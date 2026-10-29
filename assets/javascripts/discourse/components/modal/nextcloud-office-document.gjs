import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import { officeErrorMessage } from "../../lib/office-errors.js";
import { markdownLink } from "../../lib/office-markdown.js";

export default class NextcloudOfficeDocument extends Component {
  @service composer;
  @service nextcloudOffice;

  @tracked error = null;
  @tracked saving = false;
  @tracked result = null;

  formData = {
    file_name: this.args.model.fileName,
    share_password: "",
  };

  #operationKey = this.args.model.operationKey || crypto.randomUUID();
  #origin = this.composer.model;
  #draftKey = this.composer.model?.draftKey;

  constructor() {
    super(...arguments);
    this.result = this.args.model.result;
  }

  @action
  async submit(data) {
    if (this.saving || this.result) {
      return;
    }
    this.saving = true;
    this.error = null;
    try {
      const result = await this.nextcloudOffice.createDocument(
        { ...data, file_type: this.args.model.fileType },
        this.#operationKey
      );
      if (this.isDestroying) {
        return;
      }
      this.result = result;
      if (
        this.composer.model === this.#origin &&
        this.composer.model?.draftKey === this.#draftKey
      ) {
        this.args.model.toolbarEvent.addText(markdownLink(result));
        this.args.closeModal();
      }
    } catch (error) {
      if (!this.isDestroying) {
        this.error = officeErrorMessage(error);
      }
    } finally {
      if (!this.isDestroying) {
        this.saving = false;
      }
    }
  }

  <template>
    <DModal
      class="nextcloud-office-document"
      @closeModal={{@closeModal}}
      @title={{i18n "nextcloud_office.title"}}
    >
      <:body>
        <p>{{i18n "nextcloud_office.public_link"}}</p>
        {{#if @model.operationKey}}
          <p>{{i18n "nextcloud_office.resume"}}</p>
        {{/if}}
        {{#if this.result}}
          <p>{{i18n "nextcloud_office.ready"}}</p>
          <a href={{this.result.url}} rel="noopener noreferrer" target="_blank">
            {{this.result.file_name}}
          </a>
        {{else}}
          {{#if this.error}}
            <p class="alert alert-error" role="alert">{{this.error}}</p>
          {{/if}}
          <Form @data={{this.formData}} @onSubmit={{this.submit}} as |form|>
            <form.Field
              @name="file_name"
              @title={{i18n "nextcloud_office.file_name"}}
              @type="input"
              @validation="required"
              as |field|
            >
              <field.Control autofocus disabled={{this.saving}} />
            </form.Field>
            <form.Field
              @name="share_password"
              @title={{i18n "nextcloud_office.password"}}
              @type="input"
              as |field|
            >
              <field.Control
                autocomplete="new-password"
                disabled={{this.saving}}
                @type="password"
              />
            </form.Field>
            <form.Submit
              @disabled={{this.saving}}
              @isLoading={{this.saving}}
              @label="nextcloud_office.create"
            />
          </Form>
        {{/if}}
      </:body>
      <:footer>
        <DButton @action={{@closeModal}} @label="close" />
      </:footer>
    </DModal>
  </template>
}
