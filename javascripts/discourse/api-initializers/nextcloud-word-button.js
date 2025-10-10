import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.8.0", (api) => {
  // Popup-Menü-Einträge für das "+" Menü (neue API)
  api.addComposerToolbarPopupMenuOption({
    action: "createNextcloudWord",
    icon: "file",
    label: "Word Document"
  });
  
  api.addComposerToolbarPopupMenuOption({
    action: "createNextcloudExcel", 
    icon: "table",
    label: "Excel Spreadsheet"
  });
  
  api.addComposerToolbarPopupMenuOption({
    action: "createNextcloudPowerPoint",
    icon: "play", 
    label: "PowerPoint Presentation"
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
      // Dialog-HTML erstellen
      const dialogHTML = `
        <div class="nextcloud-filename-dialog-overlay">
          <div class="nextcloud-filename-dialog">
            <div class="dialog-header">
              <h3>Create ${fileTypeLabel}</h3>
            </div>
            <div class="dialog-body">
              <label class="dialog-label">File Name:</label>
              <div class="filename-input-wrapper">
                <input 
                  type="text" 
                  class="filename-input" 
                  value="${this.escapeHtml(defaultName)}"
                  placeholder="Enter file name"
                  autofocus
                />
                <span class="filename-extension">.${fileType}</span>
              </div>
              <div class="dialog-instructions">
                The file extension .${fileType} will be added automatically.
              </div>
            </div>
            <div class="dialog-footer">
              <button class="btn btn-primary dialog-confirm">Create File</button>
              <button class="btn dialog-cancel">Cancel</button>
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
      let baseName = "Document";
      
      try {
        const topicTitleInput = document.querySelector("#reply-title");
        if (topicTitleInput && topicTitleInput.value) {
          const topicTitle = topicTitleInput.value.trim();
          if (topicTitle) {
            baseName = topicTitle.substring(0, 50).replace(/[^a-zA-Z0-9äöüÄÖÜß\-_]/g, "_");
          }
        }
      } catch (e) {
        // Fallback: Standard-Name
      }
      
      // Timestamp hinzufügen
      const timestamp = new Date().toISOString().slice(0, 19).replace(/[T:]/g, "-");
      return `${baseName}_${timestamp}.${fileType}`;
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
