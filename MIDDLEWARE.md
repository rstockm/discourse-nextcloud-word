# Middleware-Dokumentation

GitHub-Datei: https://github.com/rstockm/discourse-nextcloud-word/blob/main/create-office-file.php

## Zweck

Die Middleware löst das Problem einer maximal niedrigschwelligen Integration von Collabora Online Office an beliebigen Orten einer Discourse Installation. Zwei Gedanken sind dabei entscheidend:

- die Rechtemodellerierung erfolgt ausschließlich über Discourse. Wer ein Posting innerhalb von Discourse sehen kann, hat auch Zugriff auf die Office-Datei in Collabora
- Nextclod wird nur als Hilfstechnologie verwendet um Collabora einzubinden, das System soll so transparent wie möglich im Hintergrund bleiben. Die Nutzenden sollen die eigentliche Nextcloud GUI nie sehen sondern sich freuen "oh, das war ja einfach".

Der erste Punkt folgt zunächst rein dem "Security by Obscurity" Prinzip in Form eines Hash-URL Ansatzes. Wer diese URL kennt, auch außerhalb von Discourse, hat Zugriff.

Mindestens für unseren PoC ist das ausreichend, vielleicht aber auch darüber hinaus, denn:

- niemand hindert die Teilnehmenden einer Discourse Gruppe daran, die Datei selbst ins Internet zu stellen, per Mail zu versenden etc.
- für zusätzlichen Schutz kann ein Datei-Passwort (auf Nextcloud Ebene) gesetzt werden.

Für unser Szenario - öffentliche Infrastruktur für (potentiell) öffentliche Daten - ist das erst einmal ausreichend (Setzung der Projektleitung).

Bei einer erweiterten Implementierung - etwa in Form noch auch in Nextcloud/OpenCloud sauber modellierten Rechten, etwa auch im zusammenspiel mit einem Keycloak, ist immer abzuwägen: bleibt dieser "die Nutzenden verlassen nie Discourse" Grundsatz erhalten? Wir wollen nicht das x-te überkomplexe "best-if-breed" System bauen bei dem verschiedene Tools nur lose verkoppelt und Nutzende irritiert und frustriert sind.

## Implementierung

Die Middleware verbindet die Discourse Theme Component mit Nextcloud. Discourse ruft den PHP-Endpoint `create-office-file.php` per HTTP `POST` auf. Der Endpoint erstellt auf Nextcloud eine leere Office-Datei aus einer lokalen Template-Datei und erzeugt anschliessend einen oeffentlichen Share-Link mit Lese- und Schreibrechten.

Die Middleware liegt aktuell als einzelner PHP-Endpoint im Repository vor. Sie ist nicht Teil des Discourse Themes selbst, sondern muss auf einem PHP-faehigen Webserver betrieben werden.

## Relevante Dateien

Auf dem Middleware-Server liegt der öffentliche PHP-Bereich aktuell unter `/app/data/public`. Der reale Blick auf den LAMP-Server sieht so aus:

```text
/app/data
├── apache/
└── public/
    ├── .htaccess
    ├── config.php
    ├── create-office-file.php
    ├── template.docx
    ├── template.pptx
    └── template.xlsx
```

Die für den aktuellen Middleware-Fluss relevanten Dateien sind:

- `/app/data/public/create-office-file.php`: aktiver PHP-Endpoint für Datei-Erstellung und Share-Link-Erzeugung.
- `/app/data/public/config.php`: lokale Server-Konfiguration mit Nextcloud-URL, Zugangsdaten, Zielordner und erlaubten CORS-Origins. Diese Datei gehört nicht ins GitHub-Repository.
- `/app/data/public/template.docx`, `/app/data/public/template.xlsx`, `/app/data/public/template.pptx`: lokale leere Vorlagen, aus denen neue Office-Dateien erzeugt werden.
- `/app/data/public/.htaccess`: Apache-Konfiguration für den öffentlichen Middleware-Ordner.

Im Discourse Theme Repository sind dazu diese Dateien relevant:

- `settings.yml`: Discourse Theme Setting `api_url`, das auf den Middleware-Endpoint zeigt.
- `javascripts/discourse/api-initializers/nextcloud-word-button.js`: Frontend-Integration im Discourse Composer.
- `locales/de.yml` und `locales/en.yml`: Texte für Dialog, Dateinamen und Passwort-Hinweise.

## Architektur

```text
Discourse Composer
  -> Theme JavaScript
  -> PHP-Middleware create-office-file.php
  -> Nextcloud WebDAV API
  -> Nextcloud OCS Share API
  -> Share-Link zurueck an Discourse
```

## Request vom Frontend

Das Frontend sendet bevorzugt einen JSON-Request an die in `settings.yml` konfigurierte `api_url`. Die Middleware kann zusätzlich `FormData` und `application/x-www-form-urlencoded` lesen, passend zu den vorhandenen Frontend-Fallbacks.

```json
{
  "fileName": "Beispiel.docx",
  "fileType": "docx",
  "originalFileName": "Beispiel.docx",
  "sharePassword": "optional",
  "downloadUrl": "https://discourse.example.org/uploads/short-url/beispiel.docx",
  "timestamp": "2026-05-06T21:40:00.000Z",
  "encodingMethod": "json"
}
```

Von der Middleware aktiv ausgewertet werden aktuell:

- `fileName`: Gewuenschter Dateiname inklusive oder exklusive Endung.
- `fileType`: Im Template-Modus erlaubt sind `docx`, `xlsx` und `pptx`. Im Upload-Sync-Modus sind zusaetzlich `odt`, `ods` und `odp` erlaubt.
- `sharePassword`: Optionales Passwort fuer den Nextcloud Share.
- `downloadUrl`: Optional. Wenn gesetzt, laedt die Middleware diese bereits von Discourse akzeptierte Datei herunter und verwendet sie statt einer lokalen Template-Datei.

`originalFileName`, `timestamp` und `encodingMethod` werden vom Frontend mitgesendet, aber in `create-office-file.php` nicht weiterverarbeitet.

## HTTP-Verhalten

Die Middleware setzt immer `Content-Type: application/json`.

Erlaubt sind:

- `OPTIONS`: Wird fuer CORS Preflight mit HTTP `200` beantwortet.
- `POST`: Fuehrt die Datei- und Share-Erstellung aus.

Alle anderen Methoden werden mit HTTP `405` und folgender JSON-Antwort abgelehnt:

```json
{
  "error": "Nur POST-Requests erlaubt"
}
```

## CORS

Die erlaubten Origins kommen aus `ALLOWED_ORIGINS` in `config.php`.

Wenn der Request-Origin in `ALLOWED_ORIGINS` enthalten ist, setzt die Middleware:

- `Access-Control-Allow-Origin`
- `Access-Control-Allow-Methods: POST, OPTIONS`
- `Access-Control-Allow-Headers: Content-Type`

Wenn der Origin nicht erlaubt ist, werden keine CORS-Header gesetzt.

## Erwartete Konfiguration

`create-office-file.php` laedt direkt am Anfang `config.php`. Diese Datei muss auf dem Server vorhanden sein und mindestens folgende Konstanten bereitstellen:

```php
define('ALLOWED_ORIGINS', ['https://discourse.example.org']);
define('NEXTCLOUD_URL', 'https://nextcloud.example.org');
define('NEXTCLOUD_USERNAME', 'username');
define('NEXTCLOUD_PASSWORD', 'app-password');
define('NEXTCLOUD_TARGET_FOLDER', '/Zielordner');
define('FILE_PREFIX', 'Dokument_');
define('ALLOWED_DOWNLOAD_HOSTS', ['discourse.example.org']);
define('MAX_DOWNLOAD_BYTES', 26214400);
```

`NEXTCLOUD_PASSWORD` sollte als Nextcloud App-Passwort behandelt werden und nicht im Repository liegen.

`ALLOWED_DOWNLOAD_HOSTS` ist nur fuer serverseitige Downloads im Upload-Sync-Modus zustaendig. Diese Allowlist ist bewusst von `ALLOWED_ORIGINS` getrennt, weil CORS-Freigaben und Server-to-Server-Downloads unterschiedliche Sicherheitsgrenzen sind.

## Datei-Erstellung

Die Middleware bestimmt zuerst den finalen Dateinamen:

1. Wenn kein `fileName` gesendet wurde, wird ein Name aus `FILE_PREFIX`, Datum/Uhrzeit und `fileType` erzeugt.
2. Wenn ein `fileName` gesendet wurde, bereinigt die Middleware den Namen serverseitig und stellt sicher, dass die passende Dateiendung vorhanden ist.
3. Der Dateityp wird gegen `docx`, `xlsx` und `pptx` validiert.

Danach sucht die Middleware eine lokale Template-Datei:

```text
template.docx
template.xlsx
template.pptx
```

Die passende Template-Datei wird per WebDAV `PUT` nach Nextcloud hochgeladen. Der interne Zielpfad wird aus `NEXTCLOUD_TARGET_FOLDER` und `fileName` zusammengesetzt.

## Upload-Sync-Modus

Neben dem Template-Modus kann die Middleware bestehende Dateien ueber `downloadUrl` verarbeiten. Dieser Modus ist fuer Office-Dateien gedacht, die bereits durch den nativen Discourse-Upload akzeptiert wurden.

Der Ablauf:

1. Discourse validiert und speichert die Datei ueber den normalen Composer-Upload.
2. Die Theme Component erkennt die erlaubte Endung anhand des Settings `nextcloud_upload_extensions`.
3. Die Theme Component sendet `fileName`, `fileType` und `downloadUrl` an die Middleware.
4. Die Middleware akzeptiert die URL nur, wenn sie `https` nutzt und der Host in `ALLOWED_DOWNLOAD_HOSTS` steht.
5. Die Middleware laedt die Datei mit Timeout und maximaler Groesse in ein temporaeres Systemverzeichnis.
6. Die Datei wird per WebDAV nach Nextcloud hochgeladen und danach lokal geloescht.
7. Die Middleware erstellt den Share-Link wie im Template-Modus.
8. Das Frontend ersetzt den Discourse-Anhang nur bei Erfolg durch den Nextcloud-Link.

Wenn der Upload-Sync fehlschlaegt, bleibt der normale Discourse-Anhang im Composer erhalten. Der neue Mechanismus ist damit ein Best-Effort-Sync und bricht den nativen Discourse-Upload nicht.

## Pfad-Encoding

Die Middleware trennt den internen Nextcloud-Pfad bewusst von der WebDAV-URL:

- Der interne Nextcloud-Pfad bleibt lesbar, zum Beispiel `/Meine Kategorie/Mein Dokument.docx`.
- Fuer die WebDAV-URL werden Benutzername und jedes Pfadsegment einzeln mit `rawurlencode()` encodiert.
- Slashes zwischen Ordnern bleiben erhalten und werden nicht zu `%2F`.
- Der OCS-Share-Parameter `path` bleibt der normale, nicht URL-encodierte Nextcloud-Pfad.

Dadurch funktionieren Leerzeichen und Umlaute in Dateinamen sowie in Ordner- oder Kategorienamen, ohne dass Nextcloud einen falsch zusammengesetzten WebDAV-Pfad bekommt.

Erlaubte Erfolgsstatus der WebDAV-Erstellung:

- HTTP `201`
- HTTP `204`

Andere Status fuehren zu HTTP `500` an das Frontend.

## Share-Erstellung

Nach erfolgreichem Upload erstellt die Middleware ueber die Nextcloud OCS API einen Share-Link:

```text
/ocs/v2.php/apps/files_sharing/api/v1/shares
```

Gesendete Share-Parameter:

- `path`: Zielpfad der gerade erstellten Datei.
- `shareType`: `3` fuer oeffentlichen Link.
- `permissions`: `3` fuer Lesen und Schreiben.
- `password`: Nur wenn `sharePassword` gesetzt und nach `trim()` nicht leer ist.

Damit gilt:

- Mit Passwort: Oeffentlicher Link mit Lese-/Schreibrechten und Passwortschutz.
- Ohne Passwort: Oeffentlicher Link mit Lese-/Schreibrechten nur ueber die URL.

Die Middleware akzeptiert fuer die Share-Erstellung nur HTTP `200` als Erfolg.

## Response an Discourse

Bei Erfolg gibt die Middleware folgende Struktur zurueck:

```json
{
  "success": true,
  "url": "https://nextcloud.example.org/s/shareid",
  "fileName": "Beispiel.docx",
  "fileType": "docx",
  "hasPassword": true
}
```

Das Frontend fuegt `url` anschliessend als eigenen Absatz in den Discourse Composer ein und aktualisiert die Vorschau.

## Fehlerbehandlung

Die Middleware gibt strukturierte JSON-Fehler zurueck. Wichtige Fehlerfaelle:

- Ungueltiger Dateityp: HTTP `400`.
- Fehlende Template-Datei: HTTP `500`.
- WebDAV Upload fehlgeschlagen: HTTP `500`.
- Share-Erstellung fehlgeschlagen: HTTP-Code der Nextcloud API, sofern es ein `4xx` ist, sonst HTTP `500`.
- Share-Response ohne URL: HTTP `500`.

Bei Share-Fehlern versucht die Middleware, die Nextcloud-Fehlermeldung aus JSON oder XML zu extrahieren und als `nextcloudError` an das Frontend weiterzugeben.

## Logging

Die Middleware schreibt Debug-Informationen ueber `error_log`, unter anderem:

- Dateityp und Dateiname des Requests.
- Ob ein Passwort gesetzt wurde, ohne das Passwort selbst auszugeben.
- Share-API-Fehler inklusive HTTP-Code, Response und cURL-Fehler.
- Erhaltene Share-URL oder fehlgeschlagene Response-Auswertung.

Passwoerter werden in der vorhandenen Implementierung nicht im Klartext geloggt.

## Sicherheit

Wichtige Sicherheitsannahmen und Grenzen:

- CORS wird ueber `ALLOWED_ORIGINS` begrenzt.
- Nextcloud-Zugangsdaten liegen serverseitig in `config.php` und werden nicht an Discourse ausgeliefert.
- Der oeffentliche Share erhaelt immer Lese- und Schreibrechte (`permissions = 3`).
- Ohne `sharePassword` ist der Link nur durch die nicht erratbare URL geschuetzt.
- Die Frontend-Dateinamenbereinigung entfernt problematische Pfad- und Steuerzeichen fuer die Benutzerfuehrung.
- Die Middleware bereinigt `fileName` zusaetzlich serverseitig und erlaubt dabei einfache Leerzeichen.
- Server-to-Server-Downloads sind nur von Hosts aus `ALLOWED_DOWNLOAD_HOSTS` erlaubt.
- Downloads werden auf `https`, oeffentliche IP-Ziele, Redirect-Grenzen, Timeout und `MAX_DOWNLOAD_BYTES` begrenzt.

## Betrieb und Deployment

Fuer den Betrieb muessen neben `create-office-file.php` auch `config.php` und die Template-Dateien auf dem PHP-Server vorhanden sein.

Die Discourse Theme Component muss in `settings.yml` bzw. in den Theme Settings auf die oeffentlich erreichbare Middleware-URL zeigen:

```text
https://nextdiscourse.wolkenbar.de/create-office-file.php
```

Lokale Aenderungen an dieser Dokumentation oder Middleware werden nicht automatisch nach GitHub uebertragen. Ein GitHub-Sync oder Push ist ein separater Schritt.

## Minimaler Test

Ohne Passwort:

```bash
curl -X POST "https://example.org/create-office-file.php" \
  -H "Content-Type: application/json" \
  -d '{"fileName":"test.docx","fileType":"docx"}'
```

Mit Passwort:

```bash
curl -X POST "https://example.org/create-office-file.php" \
  -H "Content-Type: application/json" \
  -d '{"fileName":"test.docx","fileType":"docx","sharePassword":"sicheres-passwort"}'
```
