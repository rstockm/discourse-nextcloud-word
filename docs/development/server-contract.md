# Serververtrag: Nextcloud Office

Stand: 2026-10-29. Maßgeblicher Entwicklungsvertrag des Changes
[`migrate-office-integration-to-plugin`](../../openspec/changes/migrate-office-integration-to-plugin/design.md).
Entwicklungs-MVP: Vorlagen-/Transfer-Endpoints erstellen Dateien und Shares,
Status liefert eigene abgeschlossene Ergebnisse, Composer-Dialog und nativer
Datei-Transfer sind implementiert. Nextcloud ist in Tests synthetisch gestubbt;
ein echter Collabora-/Nextcloud-Abnahmelauf fehlt weiterhin.

## Endpoints und Authentifizierung

| Methode/Pfad (Präfix `/nextcloud-office`) | Zweck |
| --- | --- |
| `POST /documents` | Vorlage, JSON |
| `POST /transfers` | Office-Datei, Multipart |
| `GET /operations/:operation_key` | eigener Vorgangsstatus |

Discourse-CSRF bleibt aktiv. Plugin muss aktiviert und konfiguriert sein;
erforderlich sind Browser-Sitzung und aktives, nicht gesperrtes Konto. API-Keys
werden abgelehnt, auch wenn Core sie sonst vom CSRF-Schutz ausnimmt. Origin und
der alte Theme-Key sind keine Authentifizierung. CSRF-Token über den nativen
Discourse-AJAX-Weg senden; kein eigenes Browser-Secret.

## Settings

| Setting (`nextcloud_office_…`) | Default/Regel |
| --- | --- |
| `enabled` | false; einziges Client-Setting |
| `base_url` | HTTPS-Origin ohne Pfad, Query, Userinfo oder Fragment |
| `username` | Servicekonto, keine Slashes/Steuerzeichen/Rand-Leerzeichen |
| `app_password` | serverseitig, `secret: true`; nicht leer |
| `folder` | `Discourse`; relativer Pfad, kein Traversal |
| `max_file_size_mb` | 25; Bereich 1–100, zusätzlich Discourse-Anhangslimit |

`Configuration.current.status`: `disabled`, `unconfigured` oder `ready`.
`secret: true` ist keine Verschlüsselung: Administratoren, Datenbank und Backups
bleiben Vertrauensgrenzen. Kein Secret in Client-Settings, Logs oder Fehlertexten.

## Eingaben und Namen

Erlaubte Felder: `file_name`, `file_type`, `operation_key`, `share_password`,
bei Transfers `file`. Unbekannte Felder (insbesondere `downloadUrl`) werden
abgelehnt. JSON-Parameterwrapping ist deaktiviert. Stringfelder akzeptieren
keine Arrays/Objekte und müssen gültiges UTF-8 enthalten.

- Vorlagen: docx/xlsx/pptx. Uploads zusätzlich odt/ods/odp.
- `operation_key`: 1–128 Zeichen aus ASCII-Buchstaben, Ziffern, `_`, `-`.
- `share_password`: optional, maximal 256 Bytes, keine Steuer-/Rand-Leerzeichen.
- `file_name`: optional; Default `Document`, beim Upload ursprünglicher Name.
- Namen: NFC, Pfad-/Steuer-/Bidi-Zeichen entfernen, Leerraum zusammenfassen,
  maximal 200 UTF-8-Bytes samt genau einer passenden Endung. Doppelte gleiche
  Endungen werden entfernt; widersprüchliche Office-Endungen abgelehnt.
- HTML/Markdown-Escaping ist Aufgabe des jeweiligen Ausgabekontexts, kein
  vorab HTML-kodierter Dateiname. Das Composer-Frontend escaped nur die
  Markdown-Linkbeschriftung und fügt den Link über die native Editor-API ein.

## Paketprüfung und Budgets

OOXML: Content-Types, Office-Relationship und formatspezifische Hauptteile;
ODF: unkomprimierter erster `mimetype`, Manifest und `content.xml`.
Generische ZIPs, Makro-/Verschlüsselungsmarker, Traversal, Symlinks, doppelte
Einträge, DTD/Entities und defektes XML werden abgewiesen. Keine Extraktion auf
Platte, keine Office-Ausführung oder externen XML-Netzabrufe. **Kein Virenscan.**

| Grenze | Wert |
| --- | --- |
| Datei | min(Plugin-Limit, `max_attachment_size_kb`) |
| JSON-Body | 16 KiB |
| Multipart-Body | Dateilimit + 64 KiB |
| Archiveinträge / zentrales Verzeichnis | 10.000 / 8 MiB |
| entpackter Eintrag / gesamt | 64 MiB / 250 MiB, Streaming-Bytes |
| Entpackzeit / gelesener XML-Teil | 5 s, Prüfung pro Chunk / 1 MiB |
| Mutationen Nutzer/Instanz | 5/30 pro Minute, auch Staff |
| Status Nutzer/Instanz | 30/120 pro Minute |
| parallele Mutationen Nutzer/Instanz | 2/8 |

Transfers beachten `authorized_extensions` und die zusätzliche Staff-Liste,
einschließlich Wildcards. Frequenz über Core-RateLimiter; Slots sind atomare,
besitzgebundene Redis-Leases (2 Minuten), innerhalb der Discourse-DB-Namespace.
Abgelaufene Besitzer können keine später belegten Slots freigeben. Das geplante
Operationsbudget (90 s) muss unter dieser Lease-Dauer liegen.

Rubyzip 3.7.0 verwendet `EntrySet` (Hash nach Name) und verwirft Duplikate.
Deshalb bleibt der begrenzte rohe Verzeichnisleser für Duplikat-/Modusprüfungen
vorerst erhalten. Kein neuer ZIP-Stack; tatsächliches Entpacken bleibt rubyzip.
Fixtures/Herkunft/Hashes: [Fixture-README](../../../spec/fixtures/office/README.md).

## Nextcloud-Transport

`NextcloudClient` akzeptiert nur interne absolute Pfade (`/ocs/…` etc.), keine
vollständigen URLs, `//host`, Backslashes oder eingebetteten Queries/Fragmente.
Query-Parameter werden ausschließlich durch interne Adapter explizit aufgebaut;
Nutzerparameter werden nie pauschal an Nextcloud weitergereicht.

- TLS ≥ 1.2, `VERIFY_PEER`, Hostname bleibt für Zertifikatsprüfung/SNI erhalten.
- DNS-Auflösung und IP-Filter über Core `FinalDestination::SSRFDetector`;
  Verbindung an die geprüfte IP gebunden, kein erneutes DNS-Lookup beim Connect.
- Private Ziele nur über expliziten Eintrag des Nextcloud-Hosts in Core
  `allowed_internal_hosts` (bestehende Core-Ausnahmen gelten ebenfalls).
  Keine globale Abschaltung des SSRF-Schutzes.
- Keine Proxy-Umgebungsvariablen, keine Redirects, keine automatischen Retries.
- 5 s Connect, 30 s Read/Write und **30 s gesamte Anfrage**, einschließlich
  DNS und langsamer stückweiser Antworten; 1 MiB Antwortlimit.
- Basic-Auth nur an den konfigurierten Origin; Fehler verwenden feste Codes,
  keine Rohantworten. OCS wird explizit als JSON angefordert.

Share-URL wird einmal im OCS-Adapter vollständig geprüft (Origin, Schema,
Userinfo, Share-Pfad und Token); kein separates Result-DTO. Erfolgsantwort als Hash:
`success`, `operation_key`, `url`, `file_name`, `file_type`, `has_password`.
Erfolg liefert HTTP 200; `file_name` ist der bereinigte Anzeigename ohne das
zufällige UUID-Präfix des Speicherpfads, damit eingefügte Links lesbar bleiben.
Der tatsächliche Pfad steht nur im Journal (`target_path`). Der konfigurierte
Zielordner muss vorab existieren; das Plugin legt keine Ordnerhierarchie an.
Gleichnamige Dateien erhalten verschiedene Pfade.
PUT nutzt `If-None-Match: *`; ausschließlich 201 gilt als Neuerstellung.
412 ist Konflikt; 204/Timeout ist unklar, niemals Erfolg oder blinder Retry.

OCS nutzt JSON (`format=json`, `OCS-APIRequest: true`), Share-Typ 3 und exakt
permissions=3. HTTP- und OCS-Status sowie Pfad, Eigentümer, Dateityp und
Passwortmarker (`null`/`redacted`) werden geprüft. Kein Passwort-Downgrade.
Wenn Nextcloud Rechte automatisch erweitert (z. B. Federation auf 19), wird
dieser Share nicht als Erfolg freigegeben; Zielkonfiguration separat prüfen.

## Wiederanlauf und Aufbewahrung

`nextcloud_office_operations`: Unique-Indizes pro Nutzer/Operation-Key und
Zielpfad; HMAC-SHA256-Fingerprint aus Anzeigename, Format, Datei-Digest und
optionalem Passwort. Keine Dateipayload und kein Klartextpasswort gespeichert.
Ergebnislink AES-256-GCM-verschlüsselt, Schlüssel aus Discourse secret_key_base.
Schlüsselverlust/-rotation kann Ergebnisse unlesbar machen; kein Datenverlust
an Nextcloud-Dateien, Betreiberreparatur nötig.

Ein Core-DistributedMutex serialisiert denselben Nutzer/Key (100 s Lease),
die Operation hat 90 s Gesamtbudget. Keine lange DB-Transaktion über Netzaufrufe.
Vor PUT wird `unknown` dauerhaft gespeichert. Bei Wiederholung wird die Datei
mit begrenztem Streaming-SHA256 gegen die eingereichten Bytes geprüft; erst
bei Nichtvorhandensein erneut bedingt erzeugt. Vor Share-Erstellung stets
Shares am exklusiven Pfad abfragen; mehrdeutige/abweichende Ergebnisse stoppen.
Status ist eigentümergebunden und rein lesend; unklare Vorgänge liefern 409,
Wiederanlauf benötigt denselben POST mit denselben Bytes/Passwort.
Keine periodischen Remote-Jobs und **keine automatische entfernte Löschung**.
Unklare Fälle bleiben für Betreiberreparatur sichtbar; verwaiste Dateien können
bis zum manuellen Eingriff bestehen. `Operation.purge_completed!` entfernt pro
Aufruf höchstens 500 abgeschlossene lokale Einträge älter als sieben Tage;
kein automatischer Aufruf/Remote-Job. Ungelöste Fälle bleiben erhalten.

Betreiberreparatur: Plugin bei Bedarf deaktivieren, Nutzer/Key und eindeutigen
Zielpfad im Journal bestimmen, Datei und Shares in Nextcloud kontrollieren.
Nur nach manuellem Eigentums-/Inhaltsabgleich ein Ergebnis übernehmen bzw.
verwaiste Ressourcen gezielt entfernen; niemals einen unklaren Vorgang pauschal
löschen und mit neuem Key erneut starten. Bestehende/fertige Dokumente erhalten.

## Antworten und Fehler

Office-Fehler: ausschließlich `success: false`, `error_code`, lokalisierter
`error`, `correlation_id`; Kennung auch in `X-Discourse-Office-Correlation-Id`.
`Cache-Control: no-store`, bei 429 `Retry-After`. Deaktivierung und frühere
Core-Guards können Core-Fehlerantworten liefern.

| Status | Codes |
| --- | --- |
| 400 | invalid_parameters, invalid_file_name, invalid_operation_key, file_extension_mismatch, invalid_share_password |
| 403 | not_logged_in, account_inactive, session_required, csrf_failed |
| 404 | operation_not_found; deaktiviertes Plugin |
| 409 | operation_conflict, operation_failed |
| 413 | request_too_large, file_too_large |
| 415 | unsupported_file_type, invalid_file_content, file_type_not_allowed |
| 429 | rate_limited, too_many_concurrent |
| 502 / 504 | operation_unknown (Nextcloud-Fehler bzw. 90-s-Budget) |
| 503 | not_configured, operation_unavailable |

Transportfehler bleiben intern: nextcloud_timeout, nextcloud_tls_error,
nextcloud_unavailable, nextcloud_redirect_refused, nextcloud_response_too_large,
nextcloud_private_address_refused, invalid_request_path, not_configured sowie die
WebDAV-/OCS-Fehler. Nach außen werden sie zu `operation_unknown` (502/504) oder,
bei nachgewiesenem Konflikt, `operation_conflict` (409); Rohantworten und
Upstream-Texte werden nicht übernommen.

## Composer-Frontend

- Menüaktionen für Word/Excel/PowerPoint; Dateiname wird aus Thementitel und
  lokalem Datum vorgeschlagen, das Share-Passwort ist optional.
- Der Dialog nutzt Plugin-i18n (en/de), fokussiert das Namensfeld und blockiert
  Doppel-Submits. Bei unklarem Ausgang bleibt derselbe Operation-Key aktiv;
  nach einem Entwurfswechsel wird nichts in den neuen Entwurf eingefügt, das
  Ergebnis bleibt über „Letztes Office-Dokument öffnen“ erreichbar.
- Uploads der sechs Formate werden über `addComposerUploadHandler` direkt aus
  dem Composer als Multipart gesendet (kein serverseitiger Download einer
  Discourse-URL) und über `composer:insert-text` als Markdown-Link eingefügt.
  Ein Fehler erzeugt keinen Link und kein Ersatzdokument. Bei aktiviertem Plugin
  gehen diese Endungen immer an Nextcloud; eine Fehlkonfiguration führt zu einer
  Fehlermeldung, nicht zu einem stillen Discourse-Upload. Wiederholte Auswahl
  derselben Datei (Name/Größe/Änderungszeit) verwendet denselben Key.
- Browser/Extensions können eingegebene Passwörter und eingefügte Links sehen;
  das Frontend ist keine zusätzliche Vertrauensgrenze.

## Nachweise und Betriebsgrenzen

Synthetische Tests belegen den vollständigen Ablauf (drei Vorlagen, sechs
Uploadformate, Passwort, Wiederanlauf, Konflikte) gegen gestubbte WebDAV-/OCS-
Antworten sowie beide Composer-Editoren im Browser. **Nicht bewiesen:** echter
Nextcloud-/Collabora-Roundtrip, reale Passwortrichtlinien, Proxy-/Job-/Browser-
Dumps und Logster-Persistenz. Canary-Specs prüfen nur erfasste Rails-Meldungen.
Browser/Erweiterungen können eingegebene Share-Passwörter sehen.

Controller-Prüfungen verhindern keine Vorabpufferung durch Rack/Proxy.
Request-Bodies nicht protokollieren; nginx `client_max_body_size` passend zum
Dateilimit plus Overhead setzen (bei 25 MiB mindestens 26m), Proxy-Timeout über
dem Operationsbudget. Konkrete Konfiguration und Tempfile-Cleanup im späteren
Betriebs-Runbook verifizieren, nicht als bereits getestet behandeln.

Checks: siehe [Verifikation](verification.md) und [lokale Tests](local-tests.md).
