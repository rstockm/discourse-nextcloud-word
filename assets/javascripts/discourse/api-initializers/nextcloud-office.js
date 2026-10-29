import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";
import OfficeDocument from "discourse/plugins/discourse-nextcloud-office/discourse/components/modal/nextcloud-office-document";
import { officeErrorMessage } from "../lib/office-errors.js";

const CREATE_TYPES = ["docx", "xlsx", "pptx"];
const TRANSFER_TYPES = ["docx", "xlsx", "pptx", "odt", "ods", "odp"];

export default apiInitializer((api) => {
  const settings = api.container.lookup("service:site-settings");
  if (!settings.nextcloud_office_enabled || !api.getCurrentUser()) {
    return;
  }
  const modal = api.container.lookup("service:modal");
  const composer = api.container.lookup("service:composer");
  const office = api.container.lookup("service:nextcloud-office");
  const appEvents = api.container.lookup("service:app-events");
  const dialog = api.container.lookup("service:dialog");

  for (const fileType of CREATE_TYPES) {
    api.addComposerToolbarPopupMenuOption({
      name: `nextcloud-office-${fileType}`,
      icon: "file",
      label: `nextcloud_office.${fileType}`,
      action: (toolbarEvent) => {
        const today = new Date();
        const date = [
          today.getFullYear(),
          String(today.getMonth() + 1).padStart(2, "0"),
          String(today.getDate()).padStart(2, "0"),
        ].join("-");
        const title =
          composer.model?.title || i18n("nextcloud_office.default_name");
        const pending =
          office.pendingOperation?.fileType === fileType
            ? office.pendingOperation
            : null;
        modal.show(OfficeDocument, {
          model: {
            fileType,
            fileName: pending?.fileName || `${title}_${date}.${fileType}`,
            operationKey: pending?.operationKey,
            toolbarEvent,
          },
        });
      },
    });
  }

  api.addComposerToolbarPopupMenuOption({
    name: "nextcloud-office-last-result",
    icon: "file",
    label: "nextcloud_office.last_result",
    condition: () => Boolean(office.lastResult),
    action: () =>
      modal.show(OfficeDocument, { model: { result: office.lastResult } }),
  });

  // Sends the composer's own bytes; no server-side download of a Discourse upload.
  api.addComposerUploadHandler(TRANSFER_TYPES, (files) => {
    for (const file of files) {
      office
        .transfer(file, {
          insertText: (markdown) =>
            appEvents.trigger("composer:insert-text", markdown),
        })
        .catch((error) => {
          dialog.alert(
            officeErrorMessage(error, "nextcloud_office.upload_failed")
          );
        });
    }
    return true;
  });
});
