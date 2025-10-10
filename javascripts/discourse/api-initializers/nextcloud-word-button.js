import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.8.0", (api) => {
  api.addToolbarPopupMenuOptionsCallback(() => {
    return [
      {
        id: "nextcloud_word",
        icon: "file",
        label: "Word-Dokument",
        action: (toolbarEvent) => createNextcloudDoc(toolbarEvent, "docx"),
      },
      {
        id: "nextcloud_excel",
        icon: "table",
        label: "Excel-Tabelle",
        action: (toolbarEvent) => createNextcloudDoc(toolbarEvent, "xlsx"),
      },
      {
        id: "nextcloud_powerpoint",
        icon: "play",
        label: "PowerPoint-Präsentation",
        action: (toolbarEvent) => createNextcloudDoc(toolbarEvent, "pptx"),
      },
    ];
  });

  async function createNextcloudDoc(toolbarEvent, fileType) {
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
      // Zusätzlicher Absatz nach URL für bessere UX beim Tippen
      const linkText = `\n\n${data.url}\n\n\n`;
      toolbarEvent.addText(linkText);
      
      // Onebox-Vorschau explizit triggern
      setTimeout(() => {
        const composer = toolbarEvent.composer;
        if (composer && composer.trigger) {
          composer.trigger('composer:refresh-preview');
        }
        
        // Alternative: DOM-Event für Onebox-Refresh
        const event = new Event('input', { bubbles: true });
        const textarea = document.querySelector('.d-editor-input');
        if (textarea) {
          textarea.dispatchEvent(event);
        }
      }, 100);

    } catch (error) {
      console.error("Fehler beim Erstellen der Office-Datei:", error);
      alert(`Fehler beim Erstellen der Office-Datei: ${error.message}`);
    } finally {
      // Ladezustands-Logik für Popup-Menü-Einträge ist komplexer
      // und wird hier vorerst weggelassen
    }
  }
});
