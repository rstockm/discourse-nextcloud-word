import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.8.0", (api) => {
  api.onToolbarCreate((toolbar) => {
    toolbar.addButton({
      id: "nextcloud_word",
      group: "extras",
      icon: "file-text",
      title: "Word-Dokument in Nextcloud erstellen",
      perform: (e) => createNextcloudDoc(e, "docx"),
    });
    
    toolbar.addButton({
      id: "nextcloud_excel",
      group: "extras",
      icon: "table",
      title: "Excel-Tabelle in Nextcloud erstellen",
      perform: (e) => createNextcloudDoc(e, "xlsx"),
    });
    
    toolbar.addButton({
      id: "nextcloud_powerpoint",
      group: "extras",
      icon: "play",
      title: "PowerPoint-Präsentation in Nextcloud erstellen",
      perform: (e) => createNextcloudDoc(e, "pptx"),
    });
  });

  async function createNextcloudDoc(toolbarEvent, fileType) {
    const button = document.querySelector(".nextcloud-office-button");
    if (button) {
      button.classList.add("nextcloud-office-loading");
    }

    try {
      // API-URL aus Theme-Settings (neue universelle API)
      const apiUrl = settings.api_url || "https://nextdiscourse.wolkenbar.de/create-office-file.php";
      
      // Optional: Dateiname aus Topic-Titel generieren (falls verfügbar)
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

      // URL ins Posting einfügen (nur URL für Onebox-Vorschau)
      const linkText = `\n\n${data.url}\n\n`;
      toolbarEvent.addText(linkText);

    } catch (error) {
      console.error("Fehler beim Erstellen der Office-Datei:", error);
      alert(`Fehler beim Erstellen der Office-Datei: ${error.message}`);
    } finally {
      if (button) {
        button.classList.remove("nextcloud-office-loading");
      }
    }
  }
});
