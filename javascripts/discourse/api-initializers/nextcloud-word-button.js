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
        this.createNextcloudDoc("docx");
      },
      createNextcloudExcel() {
        this.createNextcloudDoc("xlsx");
      },
      createNextcloudPowerPoint() {
        this.createNextcloudDoc("pptx");
      }
    },

    createNextcloudDoc(fileType) {
      this.createNextcloudDocAsync(fileType);
    },

    async createNextcloudDocAsync(fileType) {
      try {
        // API-URL aus Theme-Settings
        const apiUrl = settings.api_url || "https://nextdiscourse.wolkenbar.de/create-office-file.php";
        
        // Optional: Dateiname aus Topic-Titel generieren
        let fileName;
        try {
          const topicTitleInput = document.querySelector("#reply-title");
          if (topicTitleInput && topicTitleInput.value) {
            const topicTitle = topicTitleInput.value.trim();
            fileName = topicTitle 
              ? `${topicTitle.substring(0, 50).replace(/[^a-zA-Z0-9äöüÄÖÜß\-_]/g, "_")}`
              : undefined;
          }
        } catch (e) {
          // Fallback: kein Dateiname aus Titel
          fileName = undefined;
        }

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
