# Discourse Nextcloud Office

Ein Discourse-Plugin, das Office-Dokumente aus dem Composer heraus in Nextcloud
erstellt und hochgeladene Office-Dateien in bearbeitbare Nextcloud-Links
überführt. Collabora wird über Nextcloud geöffnet.

Status: **Entwicklungs-MVP**. Erstellen, Hochladen, Wiederanlauf und
Fehlerbehandlung sind lokal gegen synthetische Nextcloud-Antworten und in
Chromium getestet. Ein Abnahmelauf gegen eine echte Nextcloud-/Collabora-Instanz
steht noch aus. Der alte Theme-/PHP-Weg ist noch im Repository, aber nicht mehr
der Zielpfad (siehe [Legacy](#legacy-theme-und-php)).

## Funktionen

- Word-, Excel- und PowerPoint-Vorlage direkt im Composer erstellen
  (Plugin-Menü im Toolbar-Popup), Dateiname wird aus Thementitel und Datum
  vorgeschlagen.
- Optionales Passwort für den Nextcloud-Share.
- Hochladen von `.docx`, `.xlsx`, `.pptx`, `.odt`, `.ods` und `.odp` direkt aus
  dem Composer; die Bytes gehen an Nextcloud, das Dokument wird durch einen
  bearbeitbaren Share-Link ersetzt. Es entsteht kein Discourse-Anhang.
- Ergebnis-Link wird über die native Editor-API eingefügt und bleibt bei einem
  Entwurfswechsel außerhalb des Editors über „Letztes Office-Dokument öffnen“
  erreichbar.
- Sicherheit: nur Browser-Sitzung mit CSRF (keine API-Keys), begrenzter
  Nextcloud-Transport, kollisionsfreie Zielpfade ohne Überschreiben,
  Paketprüfung der Office-Dateien, Journal mit idempotenten Wiederholungen.

Phase 1 bleibt bewusst so: Der Share ist öffentlich bearbeitbar. Discourse-
Themen- und Gruppenrechte schützen ihn **nicht**, es gibt keine automatische
Löschung in Nextcloud und keinen Dateiabgleich. Eine Ableitung von
Discourse-Rechten wäre Phase 2.

## Voraussetzungen

- Discourse aus der geprüften Baseline (`2026.11.0-latest`-Reihe, Core-SHA
  `adf7244270b88a5485b32c7e815217e35c68b4e4`).
- Nextcloud mit aktivem Collabora-Anschluss (Nextcloud Office).
- Ein Nextcloud-Dienstkonto mit App-Passwort und Schreibrecht auf den Zielordner.
- HTTPS für Discourse und Nextcloud; Nextcloud muss vom Discourse-Server aus
  erreichbar sein.
- Die Office-Endungen müssen in Discourse als Anhänge erlaubt sein
  (`authorized_extensions`), sonst lehnt das Plugin den Upload ab.

## Installation

1. Als Admin unter **Admin → Plugins** das Repository per Git-URL installieren.
2. Plugin aktivieren und in den Einstellungen konfigurieren:

   | Setting | Bedeutung |
   | --- | --- |
   | `nextcloud_office_enabled` | Schaltet die Integration ein (Standard: aus) |
   | `nextcloud_office_base_url` | `https://cloud.example.com`, ohne Pfad/Query/Zugangsdaten |
   | `nextcloud_office_username` | Nextcloud-Dienstkonto |
   | `nextcloud_office_app_password` | App-Passwort, nur serverseitig gespeichert |
   | `nextcloud_office_folder` | Zielordner relativ zu den Dateien des Kontos |
   | `nextcloud_office_max_file_size_mb` | Obergrenze, wirksam bis zur maximalen Anhangsgröße |

3. Erst danach `nextcloud_office_enabled` einschalten; ohne vollständige
   Konfiguration antworten die Endpoints mit `not_configured`.
4. Bei privaten Nextcloud-Zielen die Freigabe in den Server-Einstellungen
   beachten (siehe [Serververtrag](docs/development/server-contract.md)).

Details zu Endpoints, Fehlercodes, Limits und Sicherheitsgrenzen:
[docs/development/server-contract.md](docs/development/server-contract.md).
Betrieb, Cutover und Rollback: [docs/development/operations.md](docs/development/operations.md).

## Verwendung

### Neues Dokument

1. Composer öffnen, im Toolbar-Popup „Word-Dokument erstellen“ (oder Excel/
   PowerPoint) wählen.
2. Dateiname prüfen und optional ein Share-Passwort setzen.
3. „Dokument erstellen“ – der Nextcloud-Link erscheint im Beitrag.

Wird die Bestätigung nicht empfangen (z. B. Timeout), zeigt der Dialog das an.
Erneut senden setzt **denselben** Vorgang fort; kein neues Dokument, kein
zweiter Share.

### Bestehende Datei

Eine Office-Datei in den Composer ziehen oder über den Anhangs-Button wählen.
Bei aktiviertem Plugin übernimmt das Plugin die Übertragung für die sechs
Formate; schlägt sie fehl, erscheint eine Fehlermeldung statt eines
Discourse-Uploads.

## Prüfen

```sh
bash script/check          # Lint, Rubocop, OpenSpec, Plugin-Specs inkl. Chromium, QUnit
bash script/check --fast   # nur statische Prüfungen
```

Die Testumgebung (Postgres 55432, Redis 56379) ist in
[docs/development/local-tests.md](docs/development/local-tests.md) beschrieben.
Was die Checks belegen und was nicht: [docs/development/verification.md](docs/development/verification.md).

## Legacy: Theme und PHP

`javascripts/`, `common/`, `locales/`, `about.json`, `settings.yml` (Theme) und
`create-office-file.php` stammen aus der alten Theme-Component mit PHP-
Middleware. Sie sind nicht Teil des Plugins (`plugin.rb` lädt nur
`lib/discourse_nextcloud_office`). Der alte Weg mit Browser-API-Key und
PHP-Zwischenserver ist unsicher und soll erst entfernt werden, wenn das Plugin
die Abnahme gegen die echte Instanz bestanden hat. Bis dahin nicht mehr
aktualisieren und in Discourse nicht mehr neu installieren.

## Support & Lizenz

Issues bitte im GitHub-Repository. MIT License, siehe [LICENSE](LICENSE).
