import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.8.0", (api) => {
  // Popup-Menü-Einträge für das "+" Menü (neue API)
  api.addComposerToolbarPopupMenuOption({
    id: "nextcloud_word",
    action: "createNextcloudWord",
    icon: "file",
    label: themePrefix("composer.word_document.label"),
    title: I18n.t(themePrefix("composer.word_document.title"))
  });
  
  api.addComposerToolbarPopupMenuOption({
    id: "nextcloud_excel", 
    action: "createNextcloudExcel",
    icon: "table",
    label: themePrefix("composer.excel_spreadsheet.label"),
    title: I18n.t(themePrefix("composer.excel_spreadsheet.title"))
  });
  
  api.addComposerToolbarPopupMenuOption({
    id: "nextcloud_powerpoint",
    action: "createNextcloudPowerPoint",
    icon: "play", 
    label: themePrefix("composer.powerpoint_presentation.label"),
    title: I18n.t(themePrefix("composer.powerpoint_presentation.title"))
  });

  // Controller-Aktionen definieren (mit pluginId)
  api.modifyClass("controller:composer", {
    pluginId: "nextcloud-office-integration",
    actions: {
      createNextcloudWord() {
        this.showFileNameModal("docx", "Word Document");
      },
      createNextcloudExcel() {
        this.showFileNameModal("xlsx", "Excel Spreadsheet");
      },
      createNextcloudPowerPoint() {
        this.showFileNameModal("pptx", "PowerPoint Presentation");
      }
    },

    showFileNameModal(fileType, fileTypeLabel) {
      // Standard-Dateiname generieren (ohne Endung)
      const defaultFileNameWithoutExt = this.generateDefaultFileName(fileType).replace(`.${fileType}`, '');
      
      // Custom Dialog erstellen
      this.showCustomDialog(defaultFileNameWithoutExt, fileType, fileTypeLabel);
    },
    
    showCustomDialog(defaultName, fileType, fileTypeLabel) {
      // Übersetzungsschlüssel basierend auf Dateityp
      const typeKeys = {
        "Word Document": "composer.word_document.title",
        "Excel Spreadsheet": "composer.excel_spreadsheet.title", 
        "PowerPoint Presentation": "composer.powerpoint_presentation.title"
      };
      
      const titleKey = typeKeys[fileTypeLabel] || "modal.create_document.heading";
      const heading = I18n.t(themePrefix(titleKey));
      
      // Dialog-HTML erstellen
      const dialogHTML = `
        <div class="nextcloud-filename-dialog-overlay">
          <div class="nextcloud-filename-dialog">
            <div class="dialog-header">
              <h3>${heading}</h3>
            </div>
            <div class="dialog-body">
              <label class="dialog-label">${I18n.t(themePrefix("modal.create_document.filename_label"))}:</label>
              <div class="filename-input-wrapper">
                <input 
                  type="text" 
                  class="filename-input" 
                  value="${this.escapeHtml(defaultName)}"
                  placeholder="${I18n.t(themePrefix("modal.create_document.filename_placeholder"))}"
                  autofocus
                />
                <span class="filename-extension">.${fileType}</span>
              </div>
              <div class="dialog-instructions">
                ${I18n.t(themePrefix("modal.create_document.extension_info"), { ext: fileType })}
              </div>
            </div>
            <div class="dialog-footer">
              <button class="btn btn-primary dialog-confirm">${I18n.t(themePrefix("modal.create_document.confirm_button"))}</button>
              <button class="btn dialog-cancel">${I18n.t(themePrefix("modal.create_document.cancel_button"))}</button>
            </div>
          </div>
        </div>
      `;
      
      // Dialog ins DOM einfügen
      const dialogElement = document.createElement('div');
      dialogElement.innerHTML = dialogHTML;
      document.body.appendChild(dialogElement);
      
      // Event-Listener
      const overlay = dialogElement.querySelector('.nextcloud-filename-dialog-overlay');
      const input = dialogElement.querySelector('.filename-input');
      const confirmBtn = dialogElement.querySelector('.dialog-confirm');
      const cancelBtn = dialogElement.querySelector('.dialog-cancel');
      
      const closeDialog = () => {
        document.body.removeChild(dialogElement);
      };
      
      const confirmAction = () => {
        const rawFileName = input.value.trim();
        if (rawFileName) {
          // Dateinamen bereinigen
          const sanitizedFileName = this.sanitizeFileName(rawFileName);
          const fullFileName = `${sanitizedFileName}.${fileType}`;
          
          // Warnung anzeigen wenn der Name geändert wurde
          if (sanitizedFileName !== rawFileName) {
            const originalFileName = rawFileName;
            const modifiedMessage = I18n.t(themePrefix("modal.create_document.filename_sanitized"), {
              original: originalFileName,
              sanitized: sanitizedFileName
            });
            
            if (!confirm(modifiedMessage)) {
              return; // Benutzer bricht ab
            }
          }
          
          closeDialog();
          this.createNextcloudDoc(fileType, fullFileName);
        }
      };
      
      // Enter-Taste für Bestätigung
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          confirmAction();
        } else if (e.key === 'Escape') {
          closeDialog();
        }
      });
      
      confirmBtn.addEventListener('click', confirmAction);
      cancelBtn.addEventListener('click', closeDialog);
      overlay.addEventListener('click', (e) => {
        if (e.target === overlay) {
          closeDialog();
        }
      });
      
      // Input fokussieren und Text selektieren
      setTimeout(() => {
        input.focus();
        input.select();
      }, 100);
    },
    
    escapeHtml(text) {
      const div = document.createElement('div');
      div.textContent = text;
      return div.innerHTML;
    },

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

    generateDefaultFileName(fileType) {
      // Topic-Titel als Basis verwenden
      let topicTitle = "";
      
      try {
        // Verschiedene Selektoren für Topic-Titel versuchen
        const topicTitleInput = document.querySelector("#reply-title") || 
                               document.querySelector("input[name='title']") ||
                               document.querySelector(".topic-title h1") ||
                               document.querySelector(".fancy-title");
        
        if (topicTitleInput) {
          // Input-Feld oder Text-Inhalt
          topicTitle = topicTitleInput.value ? topicTitleInput.value.trim() : topicTitleInput.textContent?.trim();
          
          if (topicTitle) {
            // Titel bereinigen - nur problematische Zeichen entfernen, Leerzeichen behalten
            topicTitle = topicTitle
              .replace(/[<>:"/\\|?*\x00-\x1f]/g, '')
              .replace(/\.{2,}/g, '.')
              .replace(/^\.+|\.+$/g, '')
              .substring(0, 50)
              .trim();
          }
        }
      } catch (e) {
        console.log("Could not extract topic title:", e);
      }
      
      // ISO-Datum generieren (YYYY-MM-DD)
      const now = new Date();
      const isoDate = now.toISOString().slice(0, 10); // YYYY-MM-DD
      
      // Dateiname zusammensetzen: Titel_Datum oder nur Datum falls kein Titel
      let fileName;
      if (topicTitle && topicTitle.length > 0) {
        fileName = `${topicTitle}_${isoDate}.${fileType}`;
      } else {
        const defaultPrefix = I18n.t(themePrefix("filename.default_prefix"));
        fileName = `${defaultPrefix}_${isoDate}.${fileType}`;
      }
      
      console.log("Generated filename:", fileName, "from topic title:", topicTitle);
      return fileName;
    },

    createNextcloudDoc(fileType, fileName) {
      this.createNextcloudDocAsync(fileType, fileName);
    },

    async createNextcloudDocAsync(fileType, fileName) {
      try {
        // API-URL aus Theme-Settings
        const apiUrl = settings.api_url || "https://nextdiscourse.wolkenbar.de/create-office-file.php";

        // Dateinamen nochmals bereinigen vor API-Call (zusätzliche Sicherheit)
        const sanitizedFileName = this.sanitizeFileName(fileName.replace(`.${fileType}`, '')) + `.${fileType}`;
        
        console.log("Original filename:", fileName);
        console.log("Sanitized filename:", sanitizedFileName);
        
        // API-Call zum LAMP-Server mit URL-Encoding für Dateinamen
        const response = await fetch(apiUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ 
            fileName: sanitizedFileName, 
            fileType,
            // Zusätzliche Metadaten für bessere Fehlerbehandlung
            originalFileName: fileName,
            timestamp: new Date().toISOString()
          }),
        });

        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }

        const data = await response.json();

        if (!data.success || !data.url) {
          throw new Error(data.error || "Unbekannter Fehler");
        }

        // URL ins Posting einfügen
        const linkText = `\n\n${data.url}\n\n\n`;
        this.model.appendText(linkText);
        
        // Onebox-Vorschau triggern
        setTimeout(() => {
          this.trigger('composer:refresh-preview');
        }, 100);

      } catch (error) {
        console.error("Fehler beim Erstellen der Office-Datei:", error);
        alert(`Fehler beim Erstellen der Office-Datei: ${error.message}`);
      }
    }
  });

});
