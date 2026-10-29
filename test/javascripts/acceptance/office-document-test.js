import { getOwner } from "@ember/owner";
import {
  click,
  fillIn,
  settled,
  triggerEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import OfficeDocument from "discourse/plugins/discourse-nextcloud-office/discourse/components/modal/nextcloud-office-document";

acceptance("Nextcloud Office | Document dialog", function (needs) {
  needs.user();
  needs.settings({ nextcloud_office_enabled: true });

  let calls;
  let fail;
  let switchDraft;
  let inserted;
  let composer;
  let requests;
  let transferBodies;
  let transferFail;

  needs.hooks.beforeEach(() => {
    calls = 0;
    fail = false;
    switchDraft = false;
    inserted = [];
    requests = [];
    transferBodies = [];
    transferFail = false;
  });

  needs.pretender((server, helper) => {
    server.post("/nextcloud-office/documents", (request) => {
      calls++;
      requests.push(new URLSearchParams(request.requestBody));
      if (fail) {
        return helper.response(502, { error_code: "operation_unknown" });
      }
      if (switchDraft) {
        composer.model = { draftKey: "another-draft" };
      }
      return helper.response({
        success: true,
        operation_key: requests.at(-1).get("operation_key"),
        file_name: "Plan.docx",
        file_type: "docx",
        has_password: false,
        url: "https://cloud.example.com/s/SyntheticToken",
      });
    });

    server.post("/nextcloud-office/transfers", (request) => {
      const body = request.requestBody;
      transferBodies.push({
        operationKey: body.get("operation_key"),
        fileName: body.get("file_name"),
        fileType: body.get("file_type"),
        hasFile: body.get("file") instanceof File,
      });
      if (transferFail) {
        return helper.response(502, { error_code: "operation_unknown" });
      }
      const fileName = body.get("file_name");
      return helper.response({
        success: true,
        operation_key: body.get("operation_key"),
        file_name: fileName,
        file_type: body.get("file_type"),
        has_password: false,
        url: "https://cloud.example.com/s/TransferToken",
      });
    });
  });

  async function openDialog(context) {
    await visit("/");
    const owner = getOwner(context);
    composer = owner.lookup("service:composer");
    composer.model = { draftKey: "original-draft" };
    owner.lookup("service:modal").show(OfficeDocument, {
      model: {
        fileType: "docx",
        fileName: "Plan.docx",
        ...owner.lookup("service:nextcloud-office").pendingOperation,
        toolbarEvent: { addText: (text) => inserted.push(text) },
      },
    });
    await settled();
  }

  test("creates a document with an optional password and inserts one native link", async function (assert) {
    await openDialog(this);
    assert
      .dom('.nextcloud-office-document input[name="file_name"]')
      .isFocused("the primary field receives focus");
    assert
      .dom('.nextcloud-office-document input[name="share_password"]')
      .hasAttribute("type", "password");
    await fillIn(
      '.nextcloud-office-document input[name="share_password"]',
      "synthetic-password"
    );
    await click('.nextcloud-office-document button[type="submit"]');

    assert.strictEqual(calls, 1);
    assert.strictEqual(requests[0].get("share_password"), "synthetic-password");
    assert.deepEqual(inserted, [
      "[Plan.docx](https://cloud.example.com/s/SyntheticToken)",
    ]);
    assert.dom(".nextcloud-office-document").doesNotExist();
  });

  test("submitting twice while saving sends one mutation", async function (assert) {
    await openDialog(this);
    const form = document.querySelector(".nextcloud-office-document form");
    await Promise.all([
      triggerEvent(form, "submit"),
      triggerEvent(form, "submit"),
    ]);
    await settled();

    assert.strictEqual(calls, 1);
    assert.strictEqual(inserted.length, 1);
  });

  test("cancel sends no mutation", async function (assert) {
    await openDialog(this);
    await click(".nextcloud-office-document .modal-close");
    assert.strictEqual(calls, 0);
    assert.deepEqual(inserted, []);
  });

  test("retries an uncertain outcome with the same operation key", async function (assert) {
    fail = true;
    await openDialog(this);
    await click('.nextcloud-office-document button[type="submit"]');
    assert
      .dom('.nextcloud-office-document [role="alert"]')
      .hasText(
        "The office operation is not yet confirmed. Retry the same request to check its outcome."
      );
    assert.deepEqual(inserted, []);
    fail = false;
    await click(".nextcloud-office-document .modal-close");
    await openDialog(this);
    assert
      .dom('.nextcloud-office-document input[name="share_password"]')
      .hasValue("");
    await click('.nextcloud-office-document button[type="submit"]');
    assert.strictEqual(calls, 2);
    assert.strictEqual(
      requests[0].get("operation_key"),
      requests[1].get("operation_key")
    );
    assert.strictEqual(inserted.length, 1);
  });

  test("keeps the result available without touching another draft", async function (assert) {
    switchDraft = true;
    await openDialog(this);
    await click('.nextcloud-office-document button[type="submit"]');
    assert.deepEqual(inserted, []);
    assert
      .dom(".nextcloud-office-document a")
      .hasAttribute("href", "https://cloud.example.com/s/SyntheticToken");
    assert.strictEqual(
      getOwner(this).lookup("service:nextcloud-office").lastResult.file_name,
      "Plan.docx"
    );
  });

  test("transfers all six Office formats as multipart and inserts one link each", async function (assert) {
    await visit("/");
    const office = getOwner(this).lookup("service:nextcloud-office");
    const formats = ["docx", "xlsx", "pptx", "odt", "ods", "odp"];
    const insert = (markdown) => inserted.push(markdown);

    for (const format of formats) {
      const file = new File(["synthetic"], `Upload.${format}`, {
        type: "application/octet-stream",
      });
      await office.transfer(file, { insertText: insert });
    }

    assert.strictEqual(transferBodies.length, 6);
    assert.deepEqual(
      inserted,
      formats.map(
        (format) =>
          `[Upload.${format}](https://cloud.example.com/s/TransferToken)`
      )
    );
    for (const body of transferBodies) {
      assert.true(body.hasFile, "sends the file bytes");
      assert.strictEqual(body.fileType, body.fileName.split(".").pop());
      assert.true(Boolean(body.operationKey), "sends a key");
    }
  });

  test("reports a failed transfer without inserting a link and reuses its key", async function (assert) {
    await visit("/");
    const office = getOwner(this).lookup("service:nextcloud-office");
    const makeFile = () =>
      new File(["synthetic"], "Upload.odt", {
        type: "application/octet-stream",
        lastModified: 1_700_000_000_000,
      });

    transferFail = true;
    let rejected = false;
    try {
      await office.transfer(makeFile(), {
        insertText: (markdown) => inserted.push(markdown),
      });
    } catch {
      rejected = true;
    }
    assert.true(rejected, "propagates the failure to the caller");
    assert.deepEqual(inserted, []);

    transferFail = false;
    await office.transfer(makeFile(), {
      insertText: (markdown) => inserted.push(markdown),
    });

    const keyOf = (body) => body.operationKey;
    assert.strictEqual(transferBodies.length, 2);
    assert.strictEqual(inserted.length, 1);
    assert.strictEqual(
      keyOf(transferBodies[0]),
      keyOf(transferBodies[1]),
      "the retried File keeps its operation key"
    );
  });
});
