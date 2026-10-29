# Verifikation

## Aktueller Prüfeinstieg

Ein Einstieg für alles, was dieses Projekt lokal behauptet:

```sh
bash script/check          # alle Checks
bash script/check --fast   # nur statisch, ohne DB/Redis/Browser
```

| Schritt | Befehl im Skript | Voraussetzung |
| --- | --- | --- |
| Lint/Typen | `pnpm lint` (ESLint, Stylelint, Prettier, `tsc -b`) | Node/pnpm |
| Ruby-Stil | Rubocop auf `plugin.rb lib config spec app` | `.local/bundle` |
| OpenSpec | `@fission-ai/openspec@1.15.0 validate --all --strict` | npm-Registry/Cache |
| Whitespace | `git diff --check` | nur getrackte Dateien |
| Plugin-Assets | `assets:precompile:build_plugins` | isolierter Core |
| Backend-Specs | `bin/rspec plugins/…/spec --exclude-pattern spec/system` | Postgres 55432, Redis 56379 |
| Systemtests | `bin/rspec plugins/…/spec/system` | Chromium/Playwright |
| QUnit | `bin/qunit --target discourse-nextcloud-office` | isolierter Core |

Der Legacy-Theme-Code (`javascripts/`, `common/`, `locales/`) und das PHP liegen
außerhalb dieser Lint-/Typ-Pfade; sie sind nicht mehr Ziel der Tests. Eine
Ausführung des CI-Workflows auf GitHub ist weiterhin nicht erfolgt.

`git diff --check` berücksichtigt keine untracked Dateien. Syntax-, Struktur- und
Lintchecks beweisen weder Laufzeitkompatibilität noch Sicherheit oder
funktionierende Browser-Abläufe. Die Plugin-Specs decken Boot, Deaktivierung,
native Core-Features, die Auth-/CSRF-Guard-Kette, Parameter-/Dateinamen-/
Antwortformatprüfungen, OOXML-/ODF-Struktur, Archivbudgets, Größen-/Format-/
Frequenz- und Parallelitätslimits, Secret-Hygiene, den begrenzten
Nextcloud-Transport, WebDAV/OCS, Journal/Wiederanlauf sowie Composer-Dialog und
-beide Editoren ab. Gegen echte Nextcloud-/Collabora-Instanzen wurde nichts
ausgeführt; die Adaptertests verwenden gestubbte Antworten.

Zuordnung der Spec-Szenarien zu ihren Nachweisen:
[acceptance-matrix.md](acceptance-matrix.md).

## Status und Zielmatrix

| Bereich | Heute | Abnahme im selben Change |
| --- | --- | --- |
| OpenSpec | Exakte CLI und offizielle Integration vorhanden | Change und alle Specs strikt prüfen |
| Formatierung/Lint | Plugin-Skeleton-Tooling grün; Legacy-Theme-JS ungelintet | ESLint, Stylelint, Prettier, Rubocop für allen neuen Code |
| Typen | `tsc -b` grün, noch keine Plugin-TS-Dateien | Aktueller Skeleton-/Core-Typstand, kompatibles reproduzierbares Setup |
| Frontend | QUnit 7/7: Erfolg, Abbruch, Fehler/Retry, Doppelklick, Fokus, Entwurfswechsel, sechs Formate | Manuelle Browser-Abnahme auf echter Instanz |
| Backend | 192 Plugin-Specs + 26 Systemtests grün (`bash script/check`, Exit 0) | Echte Nextcloud-/Collabora-Abnahme |
| Systemtests | Beide Editoren, Deutsch, Fehlerfluss, Retry, vier Viewports, Geometrie grün | Reale Netz-/Proxy-Bedingungen |
| Middleware | PHP lokal nicht verfügbar; Altcode unverändert | Entfernung erst nach Abnahme (6.3) |
| Browser/Accessibility | Fokus im ersten Feld, Tab-Reihenfolge, Escape, Enter-Submit, kein Abschneiden/Überlauf | WCAG-2.2-AA-Prüfung mit Hilfsmitteln |
| CI | Workflow-Datei vorhanden, auf GitHub nie ausgeführt | Offizieller Plugin-Workflow grün mit gepinntem `core_ref` |
| Deployment | Nicht geprüft | Isolierte Testinstanz, kompatible Zielversionen, Rollout/Rückweg |

Der einheitliche Prüfeinstieg wird erst mit echten Checks aufgebaut. Fehlende
Umgebung oder Tests müssen sichtbar fehlschlagen/blockieren, nicht als Erfolg gelten.
Keine eigene Vitest-/Vite-Testanwendung neben dem Discourse-Kontext ohne Bedarf.

## Erforderliche Szenarien für Folgearbeit

- Vorlagen erstellen: alle drei Office-Typen, Namen mit Umlauten, Passwort,
  sichtbare Lade-/Fehlerzustände, Doppelklick und kollisionssichere Pfade.
- Upload: unterstützte Formate, Download-/Upload-/Sharefehler, Größenlimits,
  Struktur-/MIME-Prüfung, Wiederholungen und kontrollierte Bereinigung.
- Discourse-Anhang bleibt bei Fehlern erhalten; erfolgreicher Ersatz in beiden
  Editoren; Ergebnisse verändern nach Entwurfswechsel keinen fremden Entwurf.
- Keine Secrets oder zugriffsgewährenden URLs in Logs/Fehlerantworten.
- Öffentlicher Share versus Passwortschutz; kein behaupteter Discourse-ACL-Schutz.
- Browser-Geometrie: reale Messung von Überschneidung, Abschneiden und Überlauf
  bei 1440×1000, 1024×900, 768×1024 und Smartphone ab 320 CSS-Pixeln. In den
  nativen Testweg integrieren; Funde erzeugen Exit-Code 1. Screenshots/Artefakte
  nur in git-ignorierten Ordnern und ohne echte Nutzerdaten.

## Bootstrap-Nachweis vom 2026-10-28

- OpenSpec 1.15.0: Version bestätigt, offizielle Core-Integration mit sechs
  Commands und sechs Skills erstellt; Root-/Kontextauflösung korrekt.
- Change einzeln und `validate --all --strict --no-interactive`: bestanden,
  ein Change geprüft, keine Fehler. Keine Haupt-Specs vor Archivierung erzeugt.
- Beide Node-Syntaxchecks: bestanden; kein Laufzeit-/Browsernachweis.
- Review gegen die Workflow-Szenarien sowie ADR-Status und gegenseitige
  Change-Links: bestanden. Beide ADRs bleiben `proposed`.
- Lokale Markdown-Linkziele und Whitespace einschließlich untracked
  Harness-Dateien geprüft. Dabei ein vorhandenes nachgestelltes Leerzeichen
  in der README gefunden und entfernt; anschließend erneut geprüft.
- Produktdateien stimmen mit Git-HEAD überein; nur die bestehende README wurde
  um den Einstieg/Warnhinweis und die Whitespace-Bereinigung ergänzt.
  `guidelines/` ist unversioniertes Nutzermaterial und wurde nicht bearbeitet.
- Kein Produkt-Lint, Typcheck, PHP-, Integrations-, Browser- oder Deployment-Test
  ausgeführt; fehlendes Testtooling und lokales PHP bleiben offene Grenzen.
- Keine Archivierung, Commits, Pushes oder Produktionszugriffe.

## Plugin-Gerüst vom 2026-10-28

- Offizielles Plugin-Skeleton additiv übernommen: `plugin.rb`, Engine, Routes,
  `config/settings.yml`, Locales, `Gemfile`, Skeleton-Lint-/Typkonfiguration,
  `package.json`/`pnpm-lock.yaml`, `spec/` und Plugin-CI-Workflow. Der Altcode
  (`javascripts/`, `create-office-file.php`) blieb unverändert.
- `pnpm install --frozen-lockfile` und `bundle check`: bestanden. Der Lockfile
  wurde mit pnpm 12.11.2 aus dem Skeleton-Stand erzeugt, nicht handgeändert.
- `pnpm lint` (ESLint, Stylelint, Prettier, `tsc -b`): bestanden, aber noch ohne
  Plugin-JS-Dateien; Legacy-Theme-JS wird von diesem Tooling nicht erfasst.
- Rubocop mit Plugin-Konfiguration: 5 Dateien, keine Verstöße.
- Plugin-Specs: Boot/Registrierung/Deaktivierung 3/3; native Core-Features mit
  aktivem Plugin 19/19 inklusive Plugin-JS-Assets (Chromium, isolierte DB/Redis).
- Deaktivierung wurde auf Gerüstniveau geprüft (Setting aus, vorhandene Uploads
  bleiben); Endpoint-/UI-freie Mutationsfreiheit folgt mit den späteren Einheiten.
- CI-Workflow ist angelegt und pinnt `core_ref`; auf GitHub wurde er nie
  ausgeführt. PHP, Composer-/Upload-Abläufe und Geometrieprüfungen bleiben offen.
