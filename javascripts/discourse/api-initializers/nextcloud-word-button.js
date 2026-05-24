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

  const configuredUploadExtensions = () => {
    const configured = settings.nextcloud_upload_extensions;
    const extensions = Array.isArray(configured)
      ? configured
      : (configured || "docx|xlsx|pptx|odt|ods|odp").split("|");

    return extensions
      .map((extension) => extension.toString().trim().toLowerCase().replace(/^\./, ""))
      .filter(Boolean);
  };

  const uploadExtension = (upload) => {
    const extension = upload.extension || upload.original_filename?.split(".").pop();
    return extension?.toString().toLowerCase().replace(/^\./, "");
  };

  const isDownloadableUploadUrl = (uploadUrl) => {
    return uploadUrl && !uploadUrl.startsWith("upload://") && uploadUrl !== "/404";
  };

  const absoluteUrl = (url) => new URL(url, window.location.origin).toString();

  const csrfToken = () => document.querySelector("meta[name='csrf-token']")?.content;

  const lookupUploadUrl = async (shortUrl) => {
    if (!shortUrl?.startsWith("upload://")) {
      return null;
    }

    const headers = {
      "Content-Type": "application/json"
    };
    const token = csrfToken();
    if (token) {
      headers["X-CSRF-Token"] = token;
    }

    const response = await fetch("/uploads/lookup-urls", {
      method: "POST",
      headers,
      body: JSON.stringify({ short_urls: [shortUrl] })
    });

    if (!response.ok) {
      return null;
    }

    const uploads = await response.json();
    const resolvedUpload = uploads?.[0];
    const resolvedUrl = isDownloadableUploadUrl(resolvedUpload?.url)
      ? resolvedUpload?.url
      : resolvedUpload?.short_path;

    return isDownloadableUploadUrl(resolvedUrl) ? absoluteUrl(resolvedUrl) : null;
  };

  const absoluteUploadUrl = async (upload) => {
    const candidates = [upload.url, upload.short_path];

    for (const candidate of candidates) {
      if (isDownloadableUploadUrl(candidate)) {
        return absoluteUrl(candidate);
      }
    }

    return lookupUploadUrl(upload.short_url);
  };

  const escapeRegExp = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

  const findUploadMarkdown = (reply, upload) => {
    const candidates = [upload.short_url, upload.url].filter(Boolean);

    for (const candidate of candidates) {
      const markdownMatch = reply.match(
        new RegExp(`!?\\[[^\\]\\n]+\\]\\(${escapeRegExp(candidate)}\\)`)
      );

      if (markdownMatch) {
        return markdownMatch[0];
      }
    }

    return null;
  };

  const replaceUploadedMarkdown = (upload, nextcloudUrl) => {
    const composerController = api.container.lookup("controller:composer");
    const composerModel = composerController?.model;
    const reply = composerModel?.reply || composerModel?.get?.("reply") || "";
    const originalMarkdown = findUploadMarkdown(reply, upload);

    if (!originalMarkdown) {
      return;
    }

    api.container
      .lookup("service:app-events")
      .trigger("composer:replace-text", originalMarkdown, nextcloudUrl);
  };

  const syncUploadedOfficeFile = async (upload) => {
    const extension = uploadExtension(upload);
    if (!configuredUploadExtensions().includes(extension)) {
      return;
    }

    const downloadUrl = await absoluteUploadUrl(upload);
    if (!downloadUrl) {
      console.warn("Nextcloud upload sync skipped: no downloadable upload URL", upload);
      return;
    }

    const apiUrl = settings.api_url || "https://nextdiscourse.wolkenbar.de/create-office-file.php";
    const fileName = upload.original_filename || upload.filename || `Document.${extension}`;

    try {
      const response = await fetch(apiUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          fileName,
          fileType: extension,
          downloadUrl,
          timestamp: new Date().toISOString(),
          encodingMethod: "json"
        }),
      });

      if (!response.ok) {
        console.warn("Nextcloud upload sync failed:", response.status, await response.text());
        return;
      }

      const data = await response.json();
      if (data.success && data.url) {
        replaceUploadedMarkdown(upload, data.url);
      }
    } catch (error) {
      console.warn("Nextcloud upload sync failed:", error);
    }
  };

  api.addComposerUploadMarkdownResolver((upload) => {
    syncUploadedOfficeFile(upload);
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
              <button class="dialog-close" title="${I18n.t(themePrefix("modal.create_document.close_button"))}">
                <span class="close-icon">×</span>
              </button>
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
              
              <label class="dialog-label password-label">${I18n.t(themePrefix("modal.create_document.password_label"))}:</label>
              <div class="password-input-wrapper">
                <input 
                  type="password" 
                  class="password-input" 
                  placeholder="${I18n.t(themePrefix("modal.create_document.password_placeholder"))}"
                />
              </div>
              <div class="dialog-instructions">
                ${I18n.t(themePrefix("modal.create_document.password_info"))}
              </div>
            </div>
            <div class="dialog-footer">
              <button class="btn btn-primary dialog-confirm">${I18n.t(themePrefix("modal.create_document.confirm_button"))}</button>
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
      const passwordInput = dialogElement.querySelector('.password-input');
      const confirmBtn = dialogElement.querySelector('.dialog-confirm');
      const closeBtn = dialogElement.querySelector('.dialog-close');
      
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
          
          // Passwort-Wert auslesen (kann leer sein)
          const sharePassword = passwordInput.value.trim();
          
          closeDialog();
          this.createNextcloudDoc(fileType, fullFileName, sharePassword);
        }
      };
      
      // Enter-Taste für Bestätigung (in beiden Input-Feldern)
      const handleKeyDown = (e) => {
        if (e.key === 'Enter') {
          e.preventDefault();
          confirmAction();
        } else if (e.key === 'Escape') {
          closeDialog();
        }
      };
      
      input.addEventListener('keydown', handleKeyDown);
      passwordInput.addEventListener('keydown', handleKeyDown);
      
      confirmBtn.addEventListener('click', confirmAction);
      closeBtn.addEventListener('click', closeDialog);
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
      
      // Dateinamen bereinigen - nur definitiv problematische Zeichen entfernen
      return fileName
        // Entferne nur gefährliche Pfadseparatoren und Steuerzeichen
        .replace(/[<>:"/\\|?*\x00-\x1f]/g, '')
        // Entferne mehrfache Punkte (Sicherheitsrisiko)
        .replace(/\.{2,}/g, '.')
        // Entferne führende/nachfolgende Punkte
        .replace(/^\.+|\.+$/g, '')
        // Ersetze mehrfache Leerzeichen durch einzelne
        .replace(/\s{2,}/g, ' ')
        // Begrenze Länge (ohne Dateiendung)
        .substring(0, 200)
        // Stelle sicher, dass der Name nicht leer ist
        .trim() || 'Document';
    },

    encodeFileNameForAPI(fileName) {
      // Für API-Calls: Leerzeichen und andere Sonderzeichen korrekt encodieren
      return encodeURIComponent(fileName);
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

    createNextcloudDoc(fileType, fileName, sharePassword = '') {
      this.createNextcloudDocAsync(fileType, fileName, sharePassword);
    },

    async createNextcloudDocAsync(fileType, fileName, sharePassword = '') {
      try {
        // API-URL aus Theme-Settings
        const apiUrl = settings.api_url || "https://nextdiscourse.wolkenbar.de/create-office-file.php";

        // Dateinamen bereinigen vor API-Call
        const sanitizedFileName = this.sanitizeFileName(fileName.replace(`.${fileType}`, '')) + `.${fileType}`;
        
        console.log("Original filename:", fileName);
        console.log("Sanitized filename:", sanitizedFileName);
        console.log("Share password:", sharePassword ? "***" : "(none)");
        
        // Backend-Hinweis: 
        // - Mit Passwort: permissions = 3 (read + write) + password-Schutz
        // - Ohne Passwort: permissions = 3 (read + write) - wie bisher, nur URL-basiert
        
        // API-Call zum LAMP-Server - verschiedene Encoding-Methoden versuchen
        let response;
        
        try {
          // Methode 1: Standard JSON (sollte funktionieren)
          response = await fetch(apiUrl, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ 
              fileName: sanitizedFileName, 
              fileType,
              originalFileName: fileName,
              sharePassword: sharePassword || null, // null wenn leer, sonst Passwort
              timestamp: new Date().toISOString(),
              encodingMethod: 'json'
            }),
          });
        } catch (error) {
          console.log("JSON method failed, trying FormData:", error);
          
          try {
            // Methode 2: Form Data (für problematische Zeichen)
            const formData = new FormData();
            formData.append('fileName', sanitizedFileName);
            formData.append('fileType', fileType);
            formData.append('originalFileName', fileName);
            formData.append('sharePassword', sharePassword || '');
            formData.append('timestamp', new Date().toISOString());
            formData.append('encodingMethod', 'formdata');
            
            response = await fetch(apiUrl, {
              method: "POST",
              body: formData
            });
          } catch (error2) {
            console.log("FormData method failed, trying URL encoding:", error2);
            
            // Methode 3: URL-encoded Parameters (für extreme Fälle)
            const params = new URLSearchParams();
            params.append('fileName', sanitizedFileName);
            params.append('fileType', fileType);
            params.append('originalFileName', fileName);
            params.append('sharePassword', sharePassword || '');
            params.append('timestamp', new Date().toISOString());
            params.append('encodingMethod', 'urlencoded');
            
            response = await fetch(apiUrl, {
              method: "POST",
              headers: {
                "Content-Type": "application/x-www-form-urlencoded",
              },
              body: params.toString()
            });
          }
        }

        if (!response.ok) {
          // Erweiterte Fehlerdiagnose
          const errorText = await response.text();
          console.error("API Error Response:", errorText);
          
          // Versuche JSON-Parsing für strukturierte Fehlermeldungen
          let errorData;
          try {
            errorData = JSON.parse(errorText);
          } catch (e) {
            errorData = { error: errorText };
          }
          
          throw new Error(`HTTP ${response.status}: ${errorData.error || errorText}`);
        }

        const data = await response.json();

        if (!data.success || !data.url) {
          console.error("API Success Response:", data);
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
