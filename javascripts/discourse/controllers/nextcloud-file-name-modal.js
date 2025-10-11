import Controller from "@ember/controller";

export default Controller.extend({
  fileName: null,
  isLoading: false,

  sanitizeFileName(fileName) {
    if (!fileName || typeof fileName !== 'string') {
      return '';
    }
    
    // Dateinamen bereinigen basierend auf Nextcloud/WebDAV Best Practices
    return fileName
      // Entferne definitiv problematische Zeichen (verursachen HTTP 500)
      .replace(/[<>:"/\\|?*\x00-\x1f]/g, '')
      // Entferne Pluszeichen (bekanntes Nextcloud Problem)
      .replace(/\+/g, '')
      // Entferne mehrfache Punkte (Sicherheitsrisiko)
      .replace(/\.{2,}/g, '.')
      // Entferne führende/nachfolgende Punkte und Leerzeichen
      .replace(/^[.\s]+|[.\s]+$/g, '')
      // Ersetze mehrfache Leerzeichen durch einzelne
      .replace(/\s{2,}/g, ' ')
      // Begrenze Länge (ohne Dateiendung)
      .substring(0, 200)
      // Stelle sicher, dass der Name nicht leer ist
      .trim() || 'Document';
  },

  init() {
    this._super(...arguments);
    this.set("fileName", this.model.fileName);
  },

  actions: {
    updateFileName(event) {
      this.set("fileName", event.target.value);
    },

    handleKeyDown(event) {
      if (event.key === "Enter" && !this.isLoading) {
        this.send("confirm");
      }
    },

    confirm() {
      if (this.isLoading) return;
      
      const rawFileName = this.fileName?.trim();
      if (!rawFileName) {
        this.dialog.alert(I18n.t(themePrefix("modal.create_document.error_empty")));
        return;
      }

      // Dateinamen bereinigen (falls sanitizeFileName verfügbar ist)
      let sanitizedFileName = rawFileName;
      if (typeof this.sanitizeFileName === 'function') {
        sanitizedFileName = this.sanitizeFileName(rawFileName);
        
        // Warnung anzeigen wenn der Name geändert wurde
        if (sanitizedFileName !== rawFileName) {
          const modifiedMessage = I18n.t(themePrefix("modal.create_document.filename_sanitized"), {
            original: rawFileName,
            sanitized: sanitizedFileName
          });
          
          if (!confirm(modifiedMessage)) {
            return; // Benutzer bricht ab
          }
        }
      }

      // Endung sicherstellen
      const fileType = this.model.fileType;
      const finalFileName = sanitizedFileName.endsWith(`.${fileType}`) 
        ? sanitizedFileName 
        : `${sanitizedFileName}.${fileType}`;

      this.set("isLoading", true);
      
      // Callback aufrufen
      this.model.onConfirm(finalFileName);
      
      // Modal schließen
      this.send("closeModal");
    },

    cancel() {
      if (this.isLoading) return;
      this.send("closeModal");
    }
  }
});
