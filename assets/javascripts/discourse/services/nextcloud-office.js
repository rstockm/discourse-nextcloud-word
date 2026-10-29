import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { markdownLink } from "../lib/office-markdown.js";

export default class NextcloudOffice extends Service {
  @tracked lastResult = null;
  @tracked pendingOperation = null;

  #uploadKeys = new Map();

  async createDocument(data, operationKey) {
    this.pendingOperation = {
      operationKey,
      fileType: data.file_type,
      fileName: data.file_name,
    };
    const result = await ajax("/nextcloud-office/documents", {
      type: "POST",
      data: { ...data, operation_key: operationKey },
    });
    this.#accept(result);
    this.pendingOperation = null;
    return result;
  }

  async transfer(file, { insertText }) {
    const fileType = file.name.split(".").pop()?.toLowerCase();
    const uploadId = `${file.name}:${file.size}:${file.lastModified}`;
    const operationKey = this.#uploadKeys.get(uploadId) || crypto.randomUUID();
    this.#rememberUpload(uploadId, operationKey);

    const data = new FormData();
    data.append("file", file, file.name);
    data.append("file_name", file.name);
    data.append("file_type", fileType);
    data.append("operation_key", operationKey);

    const result = await ajax("/nextcloud-office/transfers", {
      type: "POST",
      data,
      processData: false,
      contentType: false,
    });
    this.#uploadKeys.delete(uploadId);
    this.#accept(result);
    insertText(markdownLink(result));
    return result;
  }

  #rememberUpload(uploadId, operationKey) {
    this.#uploadKeys.set(uploadId, operationKey);
    if (this.#uploadKeys.size > 32) {
      this.#uploadKeys.delete(this.#uploadKeys.keys().next().value);
    }
  }

  #accept(result) {
    if (!result.success || !/^https:\/\//.test(result.url)) {
      throw new Error("invalid_office_result");
    }
    this.lastResult = result;
  }
}
