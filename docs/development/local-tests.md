# Isolierte lokale Testumgebung

Status: isolierte Core-Testbasis erfolgreich verifiziert am 2026-10-28.
Diese Datei beschreibt ausschließlich synthetische Tests, kein Produktionssetup.

## Abhängigkeiten und Isolation

- Core unter `.local/discourse`, exakt Commit
  `adf7244270b88a5485b32c7e815217e35c68b4e4` (detached HEAD).
- Homebrew Ruby 3.4.12, PostgreSQL 17.11 und Redis 8.10.3 installiert.
  libvips 8.18.7 und die nativen Core-Gems sind ebenfalls installiert.
- Bundler 4.0.23 unter `.local/gems`, Core-Gems unter `.local/bundle`.
  `bundle install --jobs 4` ist erfolgreich (285 Gems), ohne Änderung am Core-Lockfile.
- pnpm 12.11.2 wird über einen projektspezifischen Wrapper aufgerufen; das
  bestehende globale pnpm wird nicht ersetzt. Core-Lockfile-Installation bestanden.
- PostgreSQL: eigenes Cluster `.local/postgres`, nur Loopback-Port 55432;
  nicht das von Homebrew angelegte Standardcluster.
  Verbindung und Serverversion wurden per SQL bestätigt; Rolle `office_test`
  wurde ausschließlich in diesem Cluster angelegt.
- Redis: eigener temporärer Prozess, Loopback-Port 56379, keine Persistierung.
  Core-Tests verwenden Redis-DB 1 und löschen diese; niemals fremdes Redis nutzen.
  Verbindung mit `PING`/`PONG` bestätigt.
- Keine `brew services`, keine Shellprofil-Änderungen. Alle Laufzeit-/Browser-
  Dateien unter git-ignoriertem `.local/`; Testnachweise unter `.artifacts/`.

## Prozesse starten und stoppen

Einmalige Initialisierung eines **neuen** Projektclusters (niemals ein
vorhandenes Datenverzeichnis überschreiben):

```sh
/opt/homebrew/opt/postgresql@17/bin/initdb -D "$PWD/.local/postgres" --auth=trust --encoding=UTF8 --locale=en_US.UTF-8
```

Start nur bei freien Ports und vorhandenem, für dieses Projekt initialisiertem Cluster:

```sh
/opt/homebrew/opt/postgresql@17/bin/postgres -D "$PWD/.local/postgres" -h 127.0.0.1 -p 55432 -k "$PWD/.local"
/opt/homebrew/opt/redis/bin/redis-server --bind 127.0.0.1 --port 56379 --save "" --appendonly no --protected-mode yes --dir "$PWD/.local"
```

Jeweils eigener Terminal-/Harness-Prozess, nicht als Systemdienst registrieren.
Das Cluster verwendet Trust-Authentifizierung nur für diese lokalen,
wegwerfbaren Testdaten. Rolle `office_test` ist ausschließlich dort einzurichten.
Nicht an andere Interfaces binden.

Nach erstmaligem Start die Rolle nur im eigenen Cluster anlegen:

```sh
/opt/homebrew/opt/postgresql@17/bin/createuser -h 127.0.0.1 -p 55432 --superuser office_test
```

Gezieltes Stoppen ausschließlich dieser Prozesse:

```sh
/opt/homebrew/opt/postgresql@17/bin/pg_ctl -D "$PWD/.local/postgres" stop -m fast
/opt/homebrew/opt/redis/bin/redis-cli -h 127.0.0.1 -p 56379 shutdown nosave
```

## Testbefehle

`bash script/local-core <befehl>` prüft den Core-SHA und setzt die isolierte
Umgebung. Es entfernt geerbte Produktionsverbindungen und `TEST_ENV_NUMBER`,
weil letzteres einen anderen automatischen Redis-/DB-Testpfad auslösen würde.
Ohne weitere Variable gilt `LOAD_PLUGINS=0` (reine Core-Basis).
`OFFICE_TEST_PLUGIN=1` setzt `LOAD_PLUGINS=1`; Core bricht Plugin-Specs sonst im
Suite-Setup ab. Dadurch laden – wie in der offiziellen Plugin-CI – auch alle
mitgelieferten Core-Plugins, nicht nur dieses. Die Plugin-Specs laufen über einen
Symlink `.local/discourse/plugins/discourse-nextcloud-office` auf dieses Repository.
Alle Plugin-Migrationen der mitgelieferten Plugins sind in der isolierten
Testdatenbank angewandt.

Ausgeführte Datenbank-/Backend-Befehle:

```sh
bash script/local-core bin/rake db:create
bash script/local-core bin/rake db:migrate
bash script/local-core bin/rspec spec/requests/slugs_controller_spec.rb --format documentation
```

Ergebnis: `office_integration_test` angelegt und migriert. SQL bestätigt
`127.0.0.1:55432`, Extensions hstore/pg_trgm/unaccent/vector vorhanden.
Request-Smoke: **6 Beispiele, 0 Fehler**, einschließlich Session-/403- und
Rate-Limit-Szenarien. Das ist ein Core-Umgebungsnachweis, kein Plugin-Test.

Browserinstallation, vollständiger lokaler Core-Build und System-Smoke erfolgreich:

```sh
bash script/local-core pnpm playwright-install
bash script/local-core script/assemble_ember_build.rb
bash script/local-core bin/rspec spec/system/search_shortcut_variation_spec.rb:29 --format documentation
```

Ergebnis: nativer Chromium-Systemtest **1 Beispiel, 0 Fehler**; Suche/Fokus
mit `/` und Escape auf echtem Discourse. Core-Build kompiliert ohne geladene
Plugins und ohne vorgefertigte Asset-Downloads. Dieser Smoke ist kein Ersatz
für spätere Plugin-/Composer-/Geometrieprüfungen.

## Plugin-Gerüst prüfen

Tooling des offiziellen Plugin-Skeletons (`pnpm` 12.11.2, ESLint, Stylelint,
Prettier, `tsc -b`, Rubocop) und Plugin-CI-Workflow sind additiv angelegt; der
Altcode in `javascripts/` und `create-office-file.php` bleibt unverändert.
Das Frontend des Plugins ist noch leer; Composer-Tests folgen in Abschnitt 5.

```sh
npx --yes pnpm@12.11.2 install --frozen-lockfile
npx --yes pnpm@12.11.2 lint
BUNDLE_GEMFILE="$PWD/Gemfile" BUNDLE_PATH="$PWD/.local/bundle" \
  PATH="/opt/homebrew/opt/ruby@3.4/bin:$PWD/.local/gems/bin:$PATH" \
  .local/gems/bin/bundle exec rubocop plugin.rb lib config spec
OFFICE_TEST_PLUGIN=1 bash script/local-core bin/rake assets:precompile:build_plugins
OFFICE_TEST_PLUGIN=1 bash script/local-core bin/rspec plugins/discourse-nextcloud-office/spec/plugin_boot_spec.rb --format documentation
OFFICE_TEST_PLUGIN=1 bash script/local-core bin/rspec plugins/discourse-nextcloud-office/spec/system/core_features_spec.rb --format documentation
```

Ergebnisse vom 2026-10-28:

- `pnpm install --frozen-lockfile` und `bundle check`: Abhängigkeiten erfüllt.
- `pnpm lint`: JS, CSS, Prettier und Typen ohne Fehler (noch keine Plugin-JS-Dateien).
- Rubocop: 5 Ruby-Dateien, keine Verstöße.
- Plugin-Assets aller 47 geladenen Plugins gebaut (`assets:precompile:build_plugins`).
  Ein Plugin-Build mit `LOAD_PLUGINS=0` erzeugt **keine** Plugin-Bundles und lässt
  den Asset-Teil des Core-Feature-Smokes fehlschlagen; daher vorher mit
  `OFFICE_TEST_PLUGIN=1` bauen.
- Plugin-Boot/-Deaktivierung: **3 Beispiele, 0 Fehler** (Plugin registriert,
  Standard deaktiviert, Deaktivierung erhält vorhandene Uploads).
- Native Core-Features mit aktivem Plugin: **19 Beispiele, 0 Fehler** inklusive
  Plugin-JS-Assets, Topics, Suche, Profil, Likes und Login.

Noch offen: echte Office-Routen/UI, Composer-/Upload-Tests, Geometrieprüfung,
Ausführung der CI auf GitHub. Die Deaktivierungsprüfung ist auf diesem Stand
strukturell; sie wird mit den Endpoint-/UI-Einheiten erweitert.

Das Core-SQL-Schema benötigt zusätzlich `pgvector` passend zu PostgreSQL 17;
hier ist Version 0.8.7 installiert und vom Testcluster geladen. Keine Extension
aus einer anderen PostgreSQL-Major-Version verwenden.
