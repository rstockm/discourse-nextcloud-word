import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default apiInitializer("1.8.0", (api) => {
  api.addToolbarPopupMenuOptionsCallback(() => {
    return {
      id: "nextcloud_office",
      icon: "briefcase",
      label: "Office-Datei",
      action: (toolbarEvent) => {
        // Wird nicht direkt aufgerufen, nur für Dropdown
      },
    };
  });

  api.onToolbarCreate((toolbar) => {
    toolbar.addButton({
      id: "nextcloud_office",
      group: "extras",
      icon: "briefcase",
      title: "Office-Datei in Nextcloud erstellen",
      label: "Office",
      popupMenu: true,
      buildPopupMenuItems: () => [
        {
          id: "nextcloud_word",
          icon: "file-word",
          label: "Word",
          action: (toolbarEvent) => createNextcloudDoc(toolbarEvent, "docx"),
        },
        {
          id: "nextcloud_excel",
          icon: "file-excel",
          label: "Excel",
          action: (toolbarEvent) => createNextcloudDoc(toolbarEvent, "xlsx"),
        },
        {
          id: "nextcloud_powerpoint",
          icon: "file-powerpoint",
          label: "PowerPoint",
          action: (toolbarEvent) => createNextcloudDoc(toolbarEvent, "pptx"),
        },
      ],
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
