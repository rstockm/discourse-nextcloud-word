# Discourse Nextcloud Word Integration

Eine Discourse Theme Component, die das Erstellen von Office-Dokumenten in Nextcloud direkt aus dem Discourse Composer ermöglicht.

## Features

- ✅ Button "Word/EXCEL/PowerPoint-Datei" im Discourse Composer
- ✅ Erstellt .docx/.xlsx./pptx-Dateien in Nextcloud
- ✅ Fügt bearbeitbaren Share-Link ins Posting ein
- ✅ Automatische Dateinamengenerierung aus Topic-Titel
- ✅ Konfigurierbare API-URL via Theme-Settings

## Voraussetzungen

Diese Theme Component benötigt einen LAMP-Server als Middleware zwischen Discourse und Nextcloud. 

**Backend-Code:** Die PHP-Middleware finden Sie im Hauptprojekt-Repository.

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

**Via Manual Upload:**

1. Repository herunterladen
2. Admin-Panel → **Customize** → **Themes**  
3. **Install** → Dateien einzeln hochladen

### 2. Component aktivieren

1. Wählen Sie ein aktives Theme
2. **Include component** → `Nextcloud Word Integration`
3. **Save**

### 3. API-URL konfigurieren (optional)

Falls Ihr LAMP-Server eine andere URL hat:

1. Theme Component öffnen
2. **Settings** → `api_url` anpassen
3. **Save**

## Verwendung

1. Neuen Post oder Reply in Discourse erstellen
2. Button **"Word-Datei"** im Composer-Toolbar klicken
3. Word-Dokument wird automatisch in Nextcloud erstellt
4. Bearbeitbarer Share-Link wird ins Posting eingefügt

**Beispiel-Output:**
```markdown
📄 [Mein-Dokument.docx](https://nextcloud.domain/s/xxxxx)
```

## Konfiguration

### Theme Settings

- **api_url**: URL des LAMP-Server API-Endpoints (Standard: `https://nextdiscourse.wolkenbar.de/create-docx.php`)

### Button-Anpassungen

Um den Button anzupassen, editieren Sie `javascripts/discourse/api-initializers/nextcloud-word-button.js`:

**Icon ändern:**
```javascript
icon: "file-word"  // Andere Icons: "file", "cloud", "folder", etc.
```

**Label ändern:**
```javascript
label: "Word-Datei"  // Ihr eigener Text
```

**Position ändern:**
```javascript
group: "extras"  // Optionen: "fontStyles", "insertions", "extras"
```

## Architektur

```
Discourse Theme Component (JavaScript)
    ↓ AJAX POST
LAMP-Server Middleware (PHP)
    ↓ WebDAV + OCS API
Nextcloud (Dateispeicher)
```

## Fehlerbehebung

### Button erscheint nicht

- Prüfen Sie, ob die Component einem aktiven Theme zugewiesen ist
- Browser-Cache leeren
- Discourse-Browser-Session neu laden

### "Fehler beim Erstellen der Word-Datei"

- Prüfen Sie die API-URL in den Settings
- Öffnen Sie Browser-Console für Details (F12 → Console)
- Testen Sie die API direkt:
  ```bash
  curl -X POST https://ihre-api.domain/create-docx.php \
    -H "Content-Type: application/json" \
    -d '{"fileName": "test.docx"}'
  ```

### CORS-Fehler

Stellen Sie sicher, dass Ihre Discourse-Domain in der LAMP-Server `config.php` unter `ALLOWED_ORIGINS` eingetragen ist:

```php
define('ALLOWED_ORIGINS', ['https://ihre-discourse.domain']);
```

## Support

Bei Problemen bitte ein Issue im GitHub-Repository erstellen.

## Lizenz

MIT License - siehe LICENSE-Datei


