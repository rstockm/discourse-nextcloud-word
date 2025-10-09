# GitHub Repository Setup

Das Repository ist lokal bereit. Führen Sie diese Schritte aus, um es auf GitHub zu veröffentlichen:

## Option 1: Via GitHub Webseite (Empfohlen)

1. Gehen Sie zu https://github.com/new
2. Repository-Name: `discourse-nextcloud-word`
3. Description: `Discourse Theme Component for Nextcloud Word Document Integration`
4. Wählen Sie **Public** oder **Private**
5. **NICHT** "Initialize with README" ankreuzen (wir haben bereits alle Dateien)
6. Klicken Sie **Create repository**

7. Nach der Erstellung führen Sie lokal aus:
   ```bash
   cd /Users/rstockm/Documents/GitHub/discourse-nextcloud-word
   git push -u origin main
   ```

## Option 2: Via GitHub CLI (falls installiert)

```bash
cd /Users/rstockm/Documents/GitHub/discourse-nextcloud-word
gh repo create discourse-nextcloud-word --public --source=. --push
```

## Nach dem Push

Das Repository ist dann verfügbar unter:
```
https://github.com/rstockm/discourse-nextcloud-word
```

### Installation in Discourse

1. Discourse Admin-Panel → Customize → Themes
2. Install → From a git repository
3. URL eingeben: `https://github.com/rstockm/discourse-nextcloud-word`
4. Install klicken

Fertig! 🎉
