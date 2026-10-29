# Recherche und Grenzen

## KISS-Review 2026-10-29

Geprüfte lokale Core-Baseline unverändert:
`adf7244270b88a5485b32c7e815217e35c68b4e4`. Verwendete Core-API:
`lib/final_destination/ssrf_detector.rb` (`lookup_and_filter_ips`, explizite
Freigaben über `allowed_internal_hosts`), Net::HTTP-IP-Pinning (`ipaddr`) und
deaktivierte automatische Retries. Keine neue Dependency.
Rubyzip 3.7.0: `lib/zip/entry_set.rb:24–25` überschreibt gleichnamige Einträge
im Hash; `CentralDirectory` verwendet dieses Set. Der existierende begrenzte
Rohverzeichnisleser bleibt deshalb erhalten. Kein neuer ZIP-Parser-Ausbau.
Nachweise/Grenzen zentral im Serververtrag, Teststände in tasks.md.

## Ursprünglicher Planungsstand

Prüfdatum: **2026-10-28**. Planung, keine Installation und kein Produkt-Testlauf.
Vor Umsetzung HEAD erneut prüfen und Unterschiede im Change dokumentieren.

## Offizielle Quellen

| Quelle | Geprüfter Stand / Ergebnis |
| --- | --- |
| [Plugin-Skeleton](https://github.com/discourse/discourse-plugin-skeleton/tree/9c79225314c80e3a5328730c51ff00fa5c7984c8) | HEAD `9c79225314c80e3a5328730c51ff00fa5c7984c8`, 2026-10-19; Struktur, package.json, Plugin-Engine/Controller/Settings, tsconfig und CI gelesen |
| [Theme-Skeleton](https://github.com/discourse/discourse-theme-skeleton/tree/ddf372574ecf94f7062659f3498df403a4036907) | HEAD `ddf372574ecf94f7062659f3498df403a4036907`; gleiches aktuelles Frontend-Tooling, aber Theme-Pfade und Theme-Testworkflow |
| [Discourse Core](https://github.com/discourse/discourse/tree/adf7244270b88a5485b32c7e815217e35c68b4e4) | HEAD `adf7244270b88a5485b32c7e815217e35c68b4e4`, 2026-10-28; initiale technische Testbaseline, keine produktive Versionszusage |
| [Plugin-CI](https://github.com/discourse/.github/blob/83e5990bc53a4e0eddabda672558e29382072bd6/.github/workflows/discourse-plugin.yml) | Backend `bin/turbo_rspec`, Plugin-QUnit, Systemtests, Lint/Typen und Migrations-/Annotationsprüfungen; keine Theme-CI für das Plugin |
| [Nextcloud OCS, stable](https://docs.nextcloud.com/server/stable/developer_manual/client_apis/OCS/ocs-share-api.html) | Dokumentationsstand Nextcloud 35, 2026-09-27; öffentliche Shares `shareType=3`, Lesen/Update `permissions=3`, Passwortparameter und Share-Abfrage/Löschung |

`latest` bei Nextcloud verweist derzeit bereits auf die kommende Version 36;
deshalb zusätzlich `stable` geprüft. Produktionsversionen sind noch nicht bekannt.
HTTP-Erfolg und OCS-Anwendungsstatus sind unterschiedliche Ebenen; dokumentierte
OCS-Statuscodes nicht unbesehen mit HTTP-Codes gleichsetzen.

## Relevante Core-Befunde

Alle folgenden Pfade beziehen sich auf den oben genannten Core-Commit:

- `frontend/discourse/app/lib/uppy/composer-upload.js`: `upload-success` wartet
  das Ergebnis der Markdown-Resolver vor `textManipulation.placeholder.success`
  ab. Dadurch ist ein asynchroner Plugin-Resolver mit nativer Platzhalter-
  Ersetzung statt nachträglichem RegEx grundsätzlich möglich. Andere Resolver,
  Editorwechsel und Teardown müssen trotzdem integriert getestet werden.
- `frontend/discourse/app/components/composer-editor.gjs`: Registrierung über
  `addComposerUploadMarkdownResolver`, Bindung an den nativen Uppy-Uploadpfad.
- `frontend/discourse/app/services/modal.js`: komponentenbasierter Modal-Service
  mit Fokusrückgabe; keine klassischen Controller-Modals.
- `frontend/discourse/app/services/composer.js`: moderner Composer-Service;
  keine pauschale Annahme, dass alte `controller:composer`-Erweiterungen passend bleiben.
- `config/site_settings.yml`: serverseitige Secret-Settings mit `secret: true`
  sind Core-Konvention. Daraus folgt keine Zusage über Verschlüsselung im Ruhezustand.
- `app/controllers/uploads_controller.rb`: native Uploads haben eigene Limits.
  Der neue Multipart-Endpoint muss seine Validierung selbst erzwingen.
- `lib/file_store/base_store.rb`: `download_safe` ist deprecated, `download`/
  `download!` existieren. Ein alternativer Upload-ID-Ansatz würde zusätzliche
  Zugriffs-/Deduplizierungsprüfung brauchen und wird für Phase 1 nicht gewählt.

Ein zunächst vermuteter Pfad `lib/uppy/uppy-composer-upload.js` war nicht vorhanden;
der tatsächliche Pfad wurde anhand des Imports ermittelt. Keine Annahme eines
API-Namens allein aus alten Beispielen übernehmen.

## Tooling-Stand

Plugin-Skeleton: Node >=22, pnpm 12.11.2, `@discourse/lint-configs` 3.8.2,
ESLint 10.6.0, Prettier 3.8.1, Stylelint 17.5.0,
`@discourse/types` 2026.10.0-a5125163, TypeScript **7.1.0-dev.20260930.4**
mit `ember-content-mapper`. Vorschlag: für den ersten reproduzierbaren Stand
dieses offizielle Setup inklusive ausdrücklich markierter Vorabversion übernehmen;
bei Inkompatibilität nicht stillschweigend downgraden, sondern Plan revidieren.

## Bestand und noch fehlende Nachweise

- Gelesen: aktiver Initializer (Vorlagen-/Uploadpfad), PHP-Datei (Validierung,
  Upload/Share und Fehler), Settings, Harness und ADR 0002.
- Drei echte serverseitige Vorlagen fehlen im Repo; für Implementierung werden
  kleine synthetische makrofreie DOCX/XLSX/PPTX-Fixtures samt Herkunft benötigt.
- Keine lokale Discourse-/Ruby-/Datenbank-/Browser-Testumgebung verifiziert;
  keine Nextcloud-/Collabora-Testinstanz angefasst.
- Zielinstanz-Versionen, Storage-Art (lokal/S3), ausgehende Netzwerkbedingungen
  und Testzugänge sind vor produktiver Freigabe zu erheben. Bei abweichender
  API-Kompatibilität ist der Plan vor betroffener Umsetzung anzupassen.
- Freigabe der Plugin-Struktur bedeutet Planung, nicht Implementierung,
  ADR-Akzeptanz, Deployment oder Archivierung.

## Umsetzungsstart und erneute Prüfung

Der Nutzer hat am 2026-10-28 die Implementierung ausdrücklich freigegeben:
zuerst lokal testen, erst anschließend einen neuen Branch auf GitHub anlegen.
Produktives Deployment und Archivierung bleiben davon ausgenommen; ADRs werden
nicht automatisch auf `accepted` gesetzt.

Die erneute Quellenprüfung durch einen read-only OpenCode-Subagenten hat alle
vier oben festgehaltenen HEADs bestätigt. Der Agent hat erfolgreich abgeschlossen;
kein Neustart nötig. Keine neuen API-/Tooling-Abweichungen gegenüber dem Plan.

Zusätzlich geprüfte Core-Voraussetzungen an der festgelegten Baseline:

- `Gemfile`: Ruby >=3.4 und <4.1, Rails ~>8.1.0.
- `Gemfile.lock`: Ruby 3.4.7p58 und Bundler 4.0.23 als Referenzstand.
- Keine `.ruby-version` im geprüften Core; nicht aus einem geratenen Dateipfad ableiten.
- pnpm 12.11.2 gemäß Core und Plugin-Skeleton; Plugin benötigt Node >=22.
- Plugin-CI standardmäßig `core_ref: latest`; für den ersten reproduzierbaren
  Teststand explizit auf den festgelegten SHA setzen.
- CI-Frontend-Erkennung berücksichtigt derzeit `.js`/`.gjs`; Tests nicht
  ausschließlich in `.ts`/`.gts` ablegen und dadurch unbemerkt überspringen.

### Lokale Voraussetzungen: Blocker für Aufgabe 1.2

Tatsächlich geprüfter Zustand, einschließlich `/opt/homebrew/opt` und bekannter
Docker-/OrbStack-App-Pfade, nicht nur Shell-PATH:

| Voraussetzung | Lokal | Ergebnis |
| --- | --- | --- |
| Ruby | System-Ruby 2.6.10 | inkompatibel, kein Homebrew-Ruby gefunden |
| Bundler | 1.17.2 | nicht kompatibler Referenzstand |
| Node | 24.16.0 | erfüllt Mindestanforderung |
| pnpm | 10.20.0 | projektbezogen auf 12.11.2 umzustellen |
| PostgreSQL / Redis | keine Programme oder Homebrew-Installationen gefunden | fehlen |
| Docker / Colima / OrbStack | keine Programme oder bekannten App-Installationen gefunden | fehlen |
| Homebrew | vorhanden | Systeminstallation technisch möglich, noch nicht ausgeführt |

Keine Produkttests ausgeführt, kein Produktcode angelegt/entfernt, kein Branch
oder Push. Wahl einer nativen oder containerisierten lokalen Testumgebung ist
vor Systeminstallationen mit dem Nutzer zu klären.

### Freigegebener nativer Installationsversuch

Der Nutzer hat die Homebrew-Installation und isolierte lokale Testprozesse ohne
dauerhafte Dienste ausdrücklich freigegeben. Die offizielle macOS-Anleitung
für die festgelegte Core-Baseline wurde gelesen. Benötigt werden zusätzlich
libvips und Build-Hilfen für die nativen Core-Abhängigkeiten.

Der erste Installationsversuch mit `ruby@3.4`, `postgresql@17`, `redis`, `vips`
und `pkgconf` ist vor Paketinstallation abgebrochen:
`unknown or unsupported macOS version: :dunno`.
Tatsächliches System: macOS 27.2; installiertes Homebrew: 5.1.15. Dessen
Versionszuordnung kennt nur macOS bis 26. Die aktuelle offizielle stabile
Homebrew-Version 7.0.11 (Release 2026-10-26) kennt macOS 27 (`golden_gate`).
Quellen: Homebrew-GitHub-Releases und `Library/Homebrew/macos_version.rb`.

Keine OS-Version vorgetäuscht, keine Homebrew-Dateien gepatcht, keine Dienste
gestartet. Vor dem nötigen größeren Homebrew-Update wird gesondert gefragt;
bestehende Pakete sollen nicht pauschal mit `brew upgrade` aktualisiert werden.

Der Nutzer hat auch dieses notwendige Homebrew-Update ausdrücklich freigegeben.
`brew update` ist erfolgreich abgeschlossen; danach wurde die Installation
erneut gestartet. Kein pauschales `brew upgrade`, keine dauerhaften Dienste und
keine Anpassung der Shellprofile. Abhängige Bibliotheken können durch die
angeforderten Pakete installiert/aktualisiert werden; keine unabhängigen Updates.
Core-Checkout und spätere Testdaten liegen git-ignoriert unter `.local/`.

### Aufgabe 1.2 verifiziert

Homebrew 7.0.11, Ruby 3.4.12, Bundler 4.0.23, PostgreSQL 17.11, Redis 8.10.3,
libvips 8.18.7 und pgvector 0.8.7 sind eingerichtet. Core-Checkout am gepinnten
Commit unverändert; Bundler installiert 285 Gems projektlokal, pnpm 12.11.2
installiert den vorhandenen Lockfile-Stand erfolgreich.

- Eigener PostgreSQL-Cluster/Rolle/DB auf `127.0.0.1:55432`, SQL-Extensions bestätigt.
- Eigenes Redis auf Loopback-Port 56379, `PONG`; keine dauerhaften Dienste.
- Datenbank angelegt und migriert; Backend-Request-Smoke: 6 Beispiele, 0 Fehler.
- Vollständiger lokaler Core-Frontend-Build erfolgreich.
- Nativer RSpec-/Chromium-System-Smoke: 1 Beispiel, 0 Fehler.
- libvips erzeugt erfolgreich eine synthetische 1×1-Pixel-PNG-Datei.

Befehle/Isolation: [local-tests.md](../../../docs/development/local-tests.md).
Dies verifiziert nur die Testbasis, noch keine Plugin- oder Office-Funktion.

### Aufgabe 1.3: Plugin-Gerüst und Tooling

Additiv angelegt: `plugin.rb`, `lib/discourse_nextcloud_office/engine.rb`,
`config/routes.rb`, `config/settings.yml`, Server-Locales, Skeleton-`Gemfile`,
Rubocop-/ESLint-/Stylelint-/Prettier-/`tsconfig`-Konfiguration, `package.json`,
`pnpm-lock.yaml`, `spec/` und `.github/workflows/discourse-plugin.yml`.
Der Altcode (`javascripts/`, `create-office-file.php`, `settings.yml` des Themes)
blieb unverändert.

Beobachtungen, die für Folgearbeit gelten:

- Plugin-Settings müssen in `config/settings.yml` unter dem Schlüssel `plugins:`
  stehen; ein eigener Top-Level-Schlüssel registriert das Setting nicht.
- Core-Suite-Setup ruft bei `LOAD_PLUGINS != "1"` `DiscoursePluginRegistry.reset!`
  auf und bricht dann mit "Clearing modifiers during a plugin spec run" ab.
  Eine Plugin-Liste in `LOAD_PLUGINS` ist daher für Specs nicht nutzbar; es muss
  `LOAD_PLUGINS=1` sein und alle mitgelieferten Core-Plugins laden, wie in der
  offiziellen Plugin-CI.
- Das Plugin wird über einen Symlink in `plugins/` eingebunden; Plugin-Migrationen
  der mitgelieferten Plugins mussten einmalig mit `LOAD_PLUGINS=1` migriert werden.
- `script/assemble_ember_build.rb` baut Plugin-Bundles mit dem übergebenen
  `LOAD_PLUGINS`. Ein Build mit `LOAD_PLUGINS=0` lässt den Asset-Teil des
  Core-Feature-Smokes fehlschlagen; vor Systemtests `LOAD_PLUGINS=1` bauen.
- Der Skeleton-Lockfile ließ sich nicht unverändert übernehmen, weil
  `concurrently` in `^9.2.3` aufgelöst wurde. Eine frische Auflösung zog
  `@volar/*` 2.4.30, das TypeScript 7 als Peer ausschließt. Statt
  `strictPeerDependencies` abzuschalten, wurde der Skeleton-Lockfile als Basis
  verwendet und nur die geänderte Range neu aufgelöst (concurrently 9.2.3).
  `pnpm install --frozen-lockfile` ist danach reproduzierbar.
- TypeScript bleibt die Skeleton-Vorabversion `7.1.0-dev.20260930.4`; sie wird
  nicht unabhängig aktualisiert. Bei echten `.ts`/`.gts`-Dateien ist der
  Typcheck erneut zu bewerten.
- Plugin-CI-Workflow nutzt `core_ref: adf7244270b88a5485b32c7e815217e35c68b4e4`
  statt des Standardwerts `latest`. Auf GitHub wurde er nicht ausgeführt.

Verifikation dieses Stands: `pnpm lint` grün (noch ohne Plugin-JS), Rubocop ohne
Verstoß, Plugin-Boot/-Deaktivierung 3/3, Core-Feature-Systemsmoke 19/19 mit
aktivem Plugin. Deaktivierung ist auf Gerüstniveau geprüft; Mutationsfreiheit
folgt mit den Endpoint-/UI-Einheiten.
