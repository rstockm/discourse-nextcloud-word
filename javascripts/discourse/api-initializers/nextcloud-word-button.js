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
      // Standard-Dateiname generieren
      const defaultFileName = this.generateDefaultFileName(fileType);
      
      // Einfache Prompt-Dialog verwenden
      const userInput = prompt(
        `Enter file name for ${fileTypeLabel}:\n\nDefault: ${defaultFileName}`,
        defaultFileName
      );
      
      if (userInput && userInput.trim()) {
        const fileName = userInput.trim();
        this.createNextcloudDoc(fileType, fileName);
      }
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
