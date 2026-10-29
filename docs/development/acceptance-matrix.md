# Abnahmematrix gegen die vier Specs

Stand: 2026-10-29. Jede Zeile nennt das Szenario aus dem Change und den
Nachweis, der es lokal belegt. „Stub" bedeutet: Nextcloud antwortet über
gestubbte WebDAV-/OCS-Antworten (WebMock), kein echter Server. Ausgeführt mit
`bash script/check` (Exit 0): 192 Plugin-Specs, 26 Systemtests, 7 QUnit-Tests,
Lint/Typen, Rubocop, OpenSpec strikt, Whitespace.

Legende: **grün** = automatisierter Nachweis vorhanden, **manuell** = nur auf
einer echten Instanz prüfbar, **offen** = noch nicht geprüft.

## office-composer

| Szenario | Nachweis | Status |
| --- | --- | --- |
| Neue Datei in beiden Editoren | `spec/system/office_document_spec.rb` (Markdown/Rich, Link + Originaltext) | grün |
| Abbrechen oder Fehler | `test/javascripts/acceptance/office-document-test.js` (cancel, Fehler/Retry), Systemtest deutscher Fehlerfluss | grün |
| Erfolgreiche Übertragung | QUnit (sechs Formate, Multipart), Systemtest ODS-Upload in beiden Editoren | grün (Stub) |
| Download/Übertragung fehlgeschlagen | QUnit (Fehler ohne Link, Key-Wiederverwendung) | grün |
| Entwurfswechsel während einer Anfrage | QUnit (kein Einfügen in fremden Entwurf, `lastResult`) | grün |
| Zwei Dateien mit gleichem Namen | Request-Spec (zwei Pfade, zwei Shares), QUnit (stabiler Key je Datei) | grün (Stub) |
| Dialog per Tastatur | Systemtest: Fokus im Namensfeld, Tab zum Passwort, Escape, Enter sendet | grün |
| Deutsche Oberfläche | Systemtest mit `locale=de`: Titel, Labels, Hinweis, Fehlermeldung | grün |

## office-request-security

| Szenario | Nachweis | Status |
| --- | --- | --- |
| Gefälschter Origin und alter Browser-Key | `spec/requests/operations_controller_spec.rb` (anonym, Origin ohne Token → 403) | grün |
| Fehlender CSRF-Nachweis | dieselbe Datei (`csrf_failed`, echtes `allow_forgery_protection`) | grün |
| API-Key statt Sitzung | `session_required` vor jeder Action | grün |
| Nextcloud mit sensiblen Fehlerdaten | `secret_handling_spec.rb`, `secret_hygiene_spec.rb`, Client-Spec (keine Rohantworten) | grün |
| Fremdes Operationsergebnis | Request-Spec (IDOR → 404, `no-store`) | grün |
| ZIP als docx getarnt | `package_validator_spec.rb`, Request-Spec (415, kein Remote-Call) | grün |
| Gefährliche Paketstruktur | Traversal, Symlink, Duplikate, DTD/Entities, defektes XML | grün |
| Größe/Archivbudget | Limits- und Validator-Specs (413, Budgets) | grün |
| Anfragelimit | Rate-Limit-Specs (429, Retry-After, Slots) | grün |
| Manipulierte URL oder Redirect | `nextcloud_client_spec.rb` (keine Redirects, `downloadUrl` abgelehnt, private IPs) | grün |
| Share-Passwort nicht in Logs/Antworten | Canary-Specs, Parameterfilter | grün (nur Rails-Logs) |

## office-storage-operations

| Szenario | Nachweis | Status |
| --- | --- | --- |
| Kollision oder konkurrierender Upload | `webdav_spec.rb` (If-None-Match, 412, parallele PUTs), Request-Spec gleiche Namen | grün (Stub) |
| Doppelklick oder verlorene Antwort | Request-Spec Replay ohne Mutation, QUnit Doppel-Submit | grün (Stub) |
| Veränderte Nutzlast | Fingerprint-Konflikt → 409 | grün |
| Share-Erstellung erfolgreich | `shares_spec.rb` (JSON, Typ 3, Rechte 3, URL-Prüfung) | grün (Stub) |
| Passwortpolicy nicht erfüllt | Share-Spec (Policy-Fehler, kein Downgrade) | grün (Stub) |
| Share existiert trotz verlorener Antwort | Request-Spec Wiederfindung statt Neuanlage | grün (Stub) |
| Bereinigung nicht möglich | keine automatische Löschung; `purge_completed!` nur lokal | grün |
| Lokale Aufbewahrungsfrist | Modell-Spec (`purge_completed!`, 7 Tage, 500 pro Lauf) | grün |
| Discourse-Mitgliedschaft endet | keine Rechteableitung; Link bleibt öffentlich | Design, nicht testbar |

## office-plugin-lifecycle

| Szenario | Nachweis | Status |
| --- | --- | --- |
| Plugin deaktiviert/nicht konfiguriert | `plugin_boot_spec.rb`, `configuration_spec.rb` (503 `not_configured`) | grün |
| Qualitätsprüfung | `bash script/check` (Lint, Typen, Rubocop, OpenSpec, Specs, QUnit) | grün |
| Produktiver Zielstand weicht ab | [operations.md](operations.md) Kompatibilitätsliste | offen (echte Instanz) |
| Erfolgreicher Umstieg | [operations.md](operations.md) Cutover | offen (echte Instanz) |
| Rücknahme der Aktivierung | [operations.md](operations.md) Rollback; Boot-Spec (Deaktivierung löscht nichts) | teilweise grün |

## Nicht abgedeckt

- Echter Nextcloud-/Collabora-Roundtrip, reale Share-Passwortrichtlinien,
  automatische Rechte-Erweiterungen.
- Reverse Proxy (Body-Limits, Timeouts, TLS-Terminierung).
- Logster-/Proxy-Persistenz jenseits der von Rails erfassten Meldungen.
- Hilfsmittelgestützte WCAG-2.2-AA-Prüfung (bisher nur Fokus/Keyboard/Geometrie).
- Ausführung des CI-Workflows auf GitHub.
