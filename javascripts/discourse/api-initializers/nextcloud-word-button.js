import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.8.0", (api) => {
  // Popup-Menü-Einträge für das "+" Menü (neue API)
  api.addComposerToolbarPopupMenuOption({
    action: "createNextcloudWord",
    icon: "file",
    label: "Erstelle Word-Dokument"
  });
  
  api.addComposerToolbarPopupMenuOption({
    action: "createNextcloudExcel", 
    icon: "table",
    label: "Erstelle Excel-Tabelle"
  });
  
  api.addComposerToolbarPopupMenuOption({
    action: "createNextcloudPowerPoint",
    icon: "play", 
    label: "Erstelle PowerPoint-Präsentation"
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
      // Deutsche Labels basierend auf Dateityp
      const germanLabels = {
        "Word Document": "Word-Dokument erstellen",
        "Excel Spreadsheet": "Excel-Tabelle erstellen", 
        "PowerPoint Presentation": "PowerPoint-Präsentation erstellen"
      };
      
      // Dialog-HTML erstellen
      const dialogHTML = `
        <div class="nextcloud-filename-dialog-overlay">
          <div class="nextcloud-filename-dialog">
            <div class="dialog-header">
              <h3>${germanLabels[fileTypeLabel] || fileTypeLabel}</h3>
            </div>
            <div class="dialog-body">
              <label class="dialog-label">Dateiname:</label>
              <div class="filename-input-wrapper">
                <input 
                  type="text" 
                  class="filename-input" 
                  value="${this.escapeHtml(defaultName)}"
                  placeholder="Dateiname eingeben"
                  autofocus
                />
                <span class="filename-extension">.${fileType}</span>
              </div>
              <div class="dialog-instructions">
                Die Dateiendung .${fileType} wird automatisch hinzugefügt.
              </div>
            </div>
            <div class="dialog-footer">
              <button class="btn btn-primary dialog-confirm">Datei erstellen</button>
              <button class="btn dialog-cancel">Abbrechen</button>
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
        const fileName = input.value.trim();
        if (fileName) {
          const fullFileName = `${fileName}.${fileType}`;
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
            // Titel bereinigen für Dateinamen
            topicTitle = topicTitle.substring(0, 50)
              .replace(/[^a-zA-Z0-9äöüÄÖÜß\-_\s]/g, "")
              .replace(/\s+/g, "_")
              .replace(/^_+|_+$/g, ""); // Leading/trailing underscores entfernen
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
        fileName = `Document_${isoDate}.${fileType}`;
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

        // API-Call zum LAMP-Server
        const response = await fetch(apiUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ fileName, fileType }),
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
