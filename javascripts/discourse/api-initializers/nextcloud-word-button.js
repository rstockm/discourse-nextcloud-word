import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default apiInitializer("1.8.0", (api) => {
  api.onToolbarCreate((toolbar) => {
    toolbar.addButton({
      id: "nextcloud_word",
      group: "extras",
      icon: "file-word",
      title: "Word-Datei in Nextcloud erstellen",
      label: "Word-Datei",
      perform: (e) => createNextcloudDoc(e),
    });
  });

  async function createNextcloudDoc(toolbarEvent) {
    const button = document.querySelector(".nextcloud-word-button");
    if (button) {
      button.classList.add("nextcloud-word-loading");
    }

    try {
      // API-URL aus Theme-Settings
      const apiUrl = settings.api_url || "https://nextdiscourse.wolkenbar.de/create-docx.php";
      
      // Optional: Dateiname aus Topic-Titel generieren
      const composer = toolbarEvent.composer;
      const topicTitle = composer.get("title") || "";
      const fileName = topicTitle 
        ? `${topicTitle.substring(0, 50).replace(/[^a-zA-Z0-9äöüÄÖÜß\-_]/g, "_")}.docx`
        : undefined;

      // API-Call zum LAMP-Server
      const response = await fetch(apiUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ fileName }),
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const data = await response.json();

      if (!data.success || !data.url) {
        throw new Error(data.error || "Unbekannter Fehler");
      }

      // URL ins Posting einfügen
      const markdownLink = `\n\n📄 [${data.fileName}](${data.url})\n\n`;
      toolbarEvent.addText(markdownLink);

    } catch (error) {
      console.error("Fehler beim Erstellen der Word-Datei:", error);
      alert(`Fehler beim Erstellen der Word-Datei: ${error.message}`);
    } finally {
      if (button) {
        button.classList.remove("nextcloud-word-loading");
      }
    }
  }
});

