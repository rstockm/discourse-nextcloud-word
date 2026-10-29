# Betrieb: Installation, Abnahme, Incident, Rollback

Stand: 2026-10-29. Dieses Runbook beschreibt den Betrieb des Plugins. Es wurde
**noch nicht** auf einer echten Instanz durchgespielt; die Schritte sind aus den
getesteten Komponenten und dem [Serververtrag](server-contract.md) abgeleitet.
Ein Abnahmelauf gegen eine echte Discourse-/Nextcloud-/Collabora-Instanz steht
aus (Aufgabe 6.4 und 6.2) und ist Voraussetzung für einen produktiven Rollout.

## Betriebsmodell

- **Genau ein Schreiber:** nur das Plugin schreibt nach Nextcloud. Der alte
  PHP-Endpoint wird gesperrt bzw. deinstalliert, der Browser-API-Key rotiert.
- **Ein Dienstkonto:** alle Nutzer handeln über das Nextcloud-Servicekonto; die
  Nextcloud-Datei- und Share-Rechte sind damit einheitlich und *nicht* an
  Discourse-Rechte gebunden.
- **Öffentliche Shares bleiben öffentlich:** Phase 1 erzeugt bearbeitbare
  Link-Shares (Typ 3, Rechte 3), optional passwortgeschützt. Keine automatische
  Löschung, keine Rechte-Ableitung aus Discourse.
- **Kein Hintergrundjob:** keine periodischen Remote-Aufrufe. Der einzige
  Aufräumpfad ist `Operation.purge_completed!` für lokale Journalzeilen.
- **Deaktivieren löscht nichts:** weder Nextcloud-Dateien/Shares noch
  Discourse-Beiträge oder Uploads.

## Voraussetzungen und Kompatibilität

| Baustein | Anforderung |
| --- | --- |
| Discourse | Baseline `2026.11.0-latest`, Core-SHA `adf7244270b88a5485b32c7e815217e35c68b4e4` getestet |
| Nextcloud | WebDAV unter `/remote.php/dav/files/<user>` und OCS v2 `/ocs/v2.php`; Nextcloud Office/Collabora aktiv |
| Netz | Discourse-Server erreicht Nextcloud per HTTPS; TLS ≥ 1.2 mit gültigem Zertifikat |
| Nextcloud-Konto | App-Passwort, Schreibrecht auf den Zielordner |
| Discourse-Setting | Office-Endungen in `authorized_extensions` erlaubt |
| Zielordner | **muss vorab existieren**; das Plugin legt keine Ordner an |

Privates Nextcloud im internen Netz: Host in Core `allowed_internal_hosts`
eintragen; keine globale SSRF-Abschaltung. Nixt der Proxy, müssen
Request-Größen für Multipart (Dateilimit + 64 KiB) und die Zeitgrenzen
(5 s Connect, 30 s Read/Write, 30 s gesamt) durchgelassen werden.

## Installation (Testinstanz, z. B. Cloudron)

Cloudron betreibt Discourse als Managed App; Plugins werden dort über das
Discourse-Admin-Panel installiert, nicht durch Editieren von `app.yml`.

1. **Sicherung vorbereiten:** Cloudron-Backup der Discourse-App anstoßen und
   den aktuellen Stand (Discourse-Version) notieren.
2. **Plugin installieren** — zwei Wege:
   - *Über Git:* Admin → Plugins → *Install a plugin* → Git-URL des Repositorys,
     Branch auswählen (setzt voraus, dass ein Branch veröffentlicht ist und der
     Server GitHub erreicht). Cloudron startet die App danach neu.
   - *Ohne Git:* `bash script/package-plugin` erzeugt
     `dist/discourse-nextcloud-office-<version>.tar.gz` (nur Laufzeitdateien).
     Archiv in den Plugin-Ordner der Instanz entpacken
     (`/app/data/plugins/discourse-nextcloud-office/`) und die App neu starten.
     Nach jedem Cloudron-App-Update prüfen, ob der Ordner noch existiert.
3. **Settings setzen** (Admin → Plugins → Einstellungen), noch **ohne**
   `nextcloud_office_enabled`:
   - `nextcloud_office_base_url`: `https://cloud.example.com`
   - `nextcloud_office_username`: Dienstkonto
   - `nextcloud_office_app_password`: App-Passwort (Secret)
   - `nextcloud_office_folder`: z. B. `Discourse` (muss existieren)
   - `nextcloud_office_max_file_size_mb`: ≤ `max_attachment_size_kb`
4. **Vorprüfung ohne Aktivierung:** anonym `GET /nextcloud-office/operations/x`
   muss 403/404 liefern; mit API-Key ebenfalls 403 (`session_required`).
5. **Aktivieren:** `nextcloud_office_enabled` einschalten.
6. **Zielordner prüfen:** Datei-Liste im Nextcloud-Zielordner beobachten.

Wenn Cloudron den Git-Branch nicht auscheckt oder der Neustart das Plugin
entfernt, ist die Plugin-Installation auf dieser Instanz nicht persistent
geprüft — dann abbrechen und dokumentieren, statt weiter zu konfigurieren.

## Abnahmelauf auf der Testinstanz

Alle Schritte mit einem normalen Testkonto, nicht als Admin. Jede Zeile
notiert Ergebnis und Screenshot (nur in git-ignorierten Ordnern, keine echten
Nutzerdaten).

| # | Prüfung | Erwartung |
| --- | --- | --- |
| 1 | Word/Excel/PowerPoint im Composer-Menü | Dialog öffnet, Namensfeld hat Fokus, Vorschlag = Titel_Datum |
| 2 | Dokument mit Umlaut im Namen erstellen | Datei liegt im Zielordner, Name mit UUID-Präfix, Link im Beitrag |
| 3 | Link öffnen | Collabora öffnet den Share; Änderung speichern und erneut öffnen |
| 4 | Zwei Dokumente gleichen Namens | Zwei Dateien, kein Überschreiben, zwei Shares |
| 5 | Passwort setzen | Nextcloud verlangt das Passwort; falsches Passwort wird abgewiesen |
| 6 | Upload `.docx`, `.xlsx`, `.pptx`, `.odt`, `.ods`, `.odp` | je ein Link, kein Discourse-Anhang |
| 7 | Upload einer generischen ZIP als `.docx` | Fehlermeldung, keine Datei in Nextcloud |
| 8 | Datei über dem Limit | Fehlermeldung (413), keine Datei |
| 9 | Elfte Mutation in einer Minute | Fehler „Zu viele Office-Anfragen" (429) |
| 10 | Doppelklick auf „Dokument erstellen" | genau eine Datei, ein Share |
| 11 | Netzwerk während der Anfrage trennen und erneut senden | unbestätigt gemeldet, danach genau ein Ergebnis |
| 12 | Entwurf wechseln, während der Dialog offen ist | kein Link im fremden Entwurf, Ergebnis über „Letztes Office-Dokument öffnen" |
| 13 | UI auf Deutsch | Dialog, Fehlermeldungen und Menüeinträge deutsch |
| 14 | Tastaturbedienung | Tab-Reihenfolge, Enter sendet, Escape schließt |
| 15 | Logs des Discourse-Containers | kein App-Passwort, kein Share-Passwort, keine vollständigen Links |
| 16 | Plugin deaktivieren | Endpoint nicht erreichbar, bestehende Links und Dateien unverändert |

Fehlschläge: nicht umgehen, sondern im Change dokumentieren und den Rollout
blockieren. Die lokale Prüfung (`bash script/check`) ersetzt diesen Lauf nicht.

## Incident: unbestätigter Vorgang

Symptom: Nutzer erhält `operation_unknown` (502/504) oder das Ergebnis bleibt
leer; die Datei kann in Nextcloud bereits existieren.

1. **Nicht** neu anlegen lassen; kein neuer Operation-Key.
2. Korrelation aus der Antwort (`correlation_id`,
   `X-Discourse-Office-Correlation-Id`) notieren.
3. In der Konsole der Instanz nachsehen:

   ```ruby
   DiscourseNextcloudOffice::Operation.where(state: %w[unknown failed]).order(:created_at).last(10)
   ```

   Felder: `user_id`, `operation_key`, `target_path`, `file_name`, `state`,
   `error_code`. Es gibt bewusst **kein** Klartextpasswort und keine Dateibytes.
4. In Nextcloud Datei und Shares am `target_path` prüfen (Inhalt, Eigentümer).
5. Wenn Datei und Share korrekt sind: der Nutzer sendet dieselbe Anfrage erneut
   (gleiche Bytes, gleiches Passwort); das Plugin findet Datei und Share wieder,
   ohne Duplikate.
6. Wenn Datei fehlt/fremd ist: Datei nicht löschen, sondern Betreiberentscheidung
   dokumentieren; ggf. Plugin kurz deaktivieren und Ressourcen gezielt entfernen.
7. Verwaiste Dateien/Shares ohne Journalbezug bleiben bestehen, bis sie manuell
   geprüft entfernt werden. Es gibt keinen automatischen Löschpfad.

## Rollback

Ein Rollback ist jederzeit ohne Datenverlust an Nextcloud möglich:

1. `nextcloud_office_enabled` deaktivieren.
2. Optional Plugin entfernen (Cloudron: Admin → Plugins). Die Tabellen
   `nextcloud_office_operations` und die Zielordner-Inhalte bleiben; das Plugin
   löscht beim Entfernen nichts.
3. **Nicht** den alten PHP-Weg reaktivieren: Er ist unsicher (Browser-API-Key,
   Origin als „Authentifizierung") und wird nicht mehr aktualisiert. Nutzer
   erstellen Office-Dateien in diesem Zeitraum direkt in Nextcloud.
4. Erst nach Entfernen prüfen, dass keine Endpoint-Aufrufe mehr ankommen und
   bestehende Links in Beiträgen weiter funktionieren (sie sind Nextcloud-Links).

Deaktivierung öffnet also keinen unsicheren Altweg, sondern entfernt die
Funktion. Das ist die gewünschte Rückfallposition.

## Cutover (nach erfolgreicher Abnahme)

1. Abnahmelauf vollständig grün; Ergebnisse im Change dokumentiert.
2. Ziele, Dienstkonto und Zielordner produktiv setzen, Plugin dort **noch
   deaktiviert** installieren.
3. PHP-Endpoint sperren (Dienst stoppen/entfernen), alten Browser-Key
   widerrufen, alte Theme-Component aus Themes entfernen.
4. Plugin aktivieren; Support-Hinweis zu öffentlichen Links veröffentlichen.
5. Erste Woche: Journal auf `unknown`/`failed` beobachten.

## Offene Punkte vor Produktion

- Echter Nextcloud-/Collabora-Roundtrip, reale Passwortrichtlinien und
  Share-Konfiguration (z. B. automatische Rechte-Erweiterung).
- Verhalten hinter Reverse Proxy (Body-Limits, Timeouts, TLS).
- Entfernung des Legacy-Theme-/PHP-Codes (Aufgabe 6.3, noch nicht freigegeben).
- Persistenz der Plugin-Installation auf der Zielplattform.
