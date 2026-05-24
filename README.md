# Discourse Nextcloud Office Integration

Eine Discourse Theme Component, die das Erstellen und Synchronisieren von Office-Dokumenten in Nextcloud direkt aus dem Discourse Composer ermöglicht.

## Features

### 1. Template-Modus (Neue Dateien erstellen)
- ✅ Buttons für "Word", "Excel" und "PowerPoint" im Discourse Composer
- ✅ Erstellt leere `.docx`, `.xlsx` oder `.pptx` Dateien in Nextcloud
- ✅ Eigener Dialog zur Eingabe des Dateinamens (mit Vorschlag aus dem Topic-Titel)
- ✅ Optional: Vergabe eines Passworts für den Nextcloud-Share direkt im Dialog
- ✅ Fügt einen bearbeitbaren Share-Link als Markdown ins Posting ein

### 2. Hybrid-Upload-Modus (Bestehende Dateien synchronisieren)
- ✅ Erkennt automatisch Office-Dateien, die per Drag & Drop in Discourse hochgeladen werden
- ✅ Lädt die Datei im Hintergrund (mit Nutzer-Cookies) herunter und sendet sie an die Middleware
- ✅ Ersetzt den nativen Discourse-Anhang automatisch durch einen Nextcloud-Share-Link
- ✅ Konfigurierbare Dateiendungen (Standard: `docx, xlsx, pptx, odt, ods, odp`)

### 3. Sicherheit (Defense in Depth)
- ✅ **API-Key:** Absicherung der Middleware durch einen Shared Secret (`X-API-Key`)
- ✅ **Origin-Prüfung:** Harte Blockade von Requests außerhalb der Discourse-Domain
- ✅ **MIME-Validierung:** Serverseitige Prüfung der "Magic Bytes" (Schutz vor getarnten `.exe` oder `.php` Dateien)
- ✅ **Sanitization:** Strikte Bereinigung von Dateinamen gegen Path Traversal

## Voraussetzungen

Diese Theme Component benötigt einen LAMP-Server als Middleware zwischen Discourse und Nextcloud. 

**Backend-Code:** Die PHP-Middleware (`create-office-file.php`) und die zugehörige Dokumentation finden Sie im Hauptprojekt-Repository.
👉 **[Details zur Middleware-Einrichtung lesen (MIDDLEWARE.md)](MIDDLEWARE.md)**

## Installation

### 1. Theme Component installieren

**Via GitHub (empfohlen):**

1. Als Admin in Discourse einloggen
2. Admin-Panel → **Customize** → **Themes**
3. **Install** → **From a git repository**
4. Repository-URL eingeben:
   ```
   https://github.com/rstockm/discourse-nextcloud-word
   ```
5. **Install** klicken

### 2. Component aktivieren

1. Wählen Sie ein aktives Theme
2. **Include component** → `Nextcloud Office Integration`
3. **Save**

### 3. Konfiguration (Settings)

In den Einstellungen der Theme Component müssen folgende Werte konfiguriert werden:

- **`api_url`**: URL des LAMP-Server API-Endpoints (z.B. `https://middleware.domain.de/create-office-file.php`)
- **`middleware_api_key`**: Der geheime API-Key zur Absicherung der Middleware. **Muss exakt mit der Konstante `MIDDLEWARE_API_KEY` in der `config.php` auf dem LAMP-Server übereinstimmen!**
- **`nextcloud_upload_extensions`**: Liste der Dateiendungen, die beim Drag & Drop automatisch zu Nextcloud synchronisiert werden sollen (Standard: `docx|xlsx|pptx|odt|ods|odp`).

## Verwendung

### Neue Datei erstellen
1. Neuen Post oder Reply in Discourse erstellen
2. Auf das Zahnrad-Icon (Extras) im Composer-Toolbar klicken und "Word/Excel/PowerPoint-Datei" wählen
3. Dateinamen und (optional) ein Passwort vergeben
4. Bearbeitbarer Share-Link wird ins Posting eingefügt

### Bestehende Datei hochladen
1. Eine Office-Datei (z.B. `.docx` oder `.odt`) per Drag & Drop in den Discourse-Editor ziehen
2. Warten, bis der normale Discourse-Upload abgeschlossen ist
3. Das Plugin synchronisiert die Datei im Hintergrund zu Nextcloud und ersetzt den Link automatisch

## Fehlerbehebung

### "Fehler beim Erstellen der Office-Datei"
- Prüfen Sie die `api_url` in den Settings.
- Prüfen Sie, ob der `middleware_api_key` in Discourse exakt mit der `config.php` übereinstimmt.
- Öffnen Sie die Browser-Console (F12) für detaillierte Fehlermeldungen (z.B. HTTP 403 Forbidden bei falschem API-Key).

### Der Drag & Drop Upload wird nicht synchronisiert
- Prüfen Sie, ob die Dateiendung in den Settings unter `nextcloud_upload_extensions` gelistet ist.
- Prüfen Sie, ob Ihr Discourse-Setup den Download von Dateien durch den Browser blockiert.

## Support & Lizenz

Bei Problemen bitte ein Issue im GitHub-Repository erstellen.
MIT License - siehe LICENSE-Datei


