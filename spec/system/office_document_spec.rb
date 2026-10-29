# frozen_string_literal: true

RSpec.describe "Office document creation" do
  include OfficeNextcloudHelpers
  include OfficePackageHelpers
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:composer) { PageObjects::Components::Composer.new }

  before do
    enable_current_plugin
    SiteSetting.nextcloud_office_base_url = "https://cloud.example.com"
    SiteSetting.nextcloud_office_username = "office-service"
    SiteSetting.nextcloud_office_app_password = "synthetic-app-password"
    SiteSetting.authorized_extensions =
      "jpg|png|docx|xlsx|pptx|odt|ods|odp"
    stub_office_nextcloud
  end

  def use_german(user)
    SiteSetting.default_locale = "de"
    SiteSetting.allow_user_locale = true
    user.update!(locale: "de")
  end

  %i[markdown rich].each do |mode|
    it "creates and inserts a document in the #{mode} editor without changing other text" do
      user.user_option.update!(composition_mode: UserOption.composition_mode_types[mode])
      sign_in(user)
      visit "/latest"
      find("#create-topic").click
      composer.fill_title("Synthetic office document")
      if mode == :markdown
        composer.fill_content("Keep this original text.")
      else
        composer.rich_editor.send_keys("Keep this original text.")
      end
      find(".toolbar-menu__options-trigger").click
      find("button[data-name='nextcloud-office-docx']").click
      expect(page).to have_css(".nextcloud-office-document")

      [[1440, 1000], [1024, 900], [768, 1024], [320, 800]].each do |width, height|
        page.current_window.resize_to(width, height)
        findings = page.evaluate_script(<<~JS)
          (() => {
            const modal = document.querySelector('.nextcloud-office-document');
            const controls = [...modal.querySelectorAll('input, button')].filter(el => el.getClientRects().length);
            const findings = [];
            const boxes = controls.map(el => ({tag: el.tagName, rect: el.getBoundingClientRect()}));
            for (const box of boxes) {
              if (box.rect.left < -1 || box.rect.right > innerWidth + 1 || box.rect.top < -1 || box.rect.bottom > innerHeight + 1) {
                findings.push('clipped ' + box.tag);
              }
            }
            for (let i = 0; i < boxes.length; i++) {
              for (let j = i + 1; j < boxes.length; j++) {
                const a = boxes[i].rect, b = boxes[j].rect;
                if (Math.min(a.right, b.right) - Math.max(a.left, b.left) > 1 && Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top) > 1) {
                  findings.push('overlap');
                }
              }
            }
            if (modal.scrollWidth > modal.clientWidth + 1) { findings.push('horizontal overflow'); }
            return findings;
          })()
        JS
        expect(findings).to eq([]), "#{width}x#{height}: #{findings.join(', ')}"
      end
      page.current_window.resize_to(1440, 1000)
      find('.nextcloud-office-document input[name="file_name"]').fill_in(with: "Synthetic.docx")
      find('.nextcloud-office-document button[type="submit"]').click
      expect(page).to have_no_css(".nextcloud-office-document")
      if mode == :markdown
        expect(composer.composer_input.value).to include("Keep this original text.", "https://cloud.example.com/s/")
      else
        expect(composer.rich_editor).to have_css('a[href^="https://cloud.example.com/s/"]')
        expect(composer.rich_editor).to have_content("Keep this original text.")
      end
      expect(@office_files.size).to eq(1)
    end
  end

  %i[markdown rich].each do |mode|
    it "transfers an uploaded Office file in the #{mode} editor" do
      user.user_option.update!(composition_mode: UserOption.composition_mode_types[mode])
      sign_in(user)
      visit "/latest"
      find("#create-topic").click
      composer.fill_title("Synthetic upload")

      attach_file("file-uploader", office_fixture_path("upload.ods"), make_visible: true)

      if mode == :markdown
        expect(composer).to have_value(%r{https://cloud\.example\.com/s/SyntheticToken\d+})
      else
        expect(composer.rich_editor).to have_css('a[href^="https://cloud.example.com/s/"]')
      end
      expect(@office_files.keys.grep(/-upload\.ods\z/).size).to eq(1)
    end
  end

  it "creates a document in German with keyboard only" do
    use_german(user)
    sign_in(user)
    visit "/latest"
    find("#create-topic").click
    composer.fill_title("Deutsches Dokument")
    find(".toolbar-menu__options-trigger").click
    find("button[data-name='nextcloud-office-docx']").click

    expect(page).to have_css(
      ".nextcloud-office-document h1.d-modal__title-text",
      text: "Office-Dokument erstellen",
    )
    expect(page).to have_field("Dateiname")
    expect(page).to have_button("Dokument erstellen")
    expect(page).to have_content(
      "Es entsteht ein öffentlicher Bearbeitungslink. Discourse-Themen- und Gruppenrechte schützen ihn nicht.",
    )
    expect(
      page.evaluate_script(
        "document.activeElement === document.querySelector('.nextcloud-office-document input[name=\"file_name\"]')",
      ),
    ).to eq(true)

    find('.nextcloud-office-document input[name="file_name"]').send_keys(:tab)
    expect(
      page.evaluate_script(
        "document.activeElement === document.querySelector('.nextcloud-office-document input[name=\"share_password\"]')",
      ),
    ).to eq(true)

    find('.nextcloud-office-document input[name="share_password"]').send_keys(:escape)
    expect(page).to have_no_css(".nextcloud-office-document")
    expect(@office_files).to be_empty

    find(".toolbar-menu__options-trigger").click
    find("button[data-name='nextcloud-office-docx']").click
    find('.nextcloud-office-document input[name="file_name"]').fill_in(
      with: "Tastatur.docx",
    )
    find('.nextcloud-office-document input[name="file_name"]').send_keys(:enter)

    expect(page).to have_no_css(".nextcloud-office-document")
    expect(composer).to have_value(%r{\[Tastatur\.docx\]\(https://cloud\.example\.com/s/})
    expect(@office_files.size).to eq(1)
  end

  it "shows the German error message and keeps the typed values after a failed request" do
    stub_office_nextcloud(share_failures: 1)
    use_german(user)
    sign_in(user)
    visit "/latest"
    find("#create-topic").click
    composer.fill_title("Fehlerfall")
    find(".toolbar-menu__options-trigger").click
    find("button[data-name='nextcloud-office-docx']").click
    find('.nextcloud-office-document input[name="file_name"]').fill_in(
      with: "Fehler.docx",
    )
    find('.nextcloud-office-document button[type="submit"]').click

    expect(page).to have_css(
      ".nextcloud-office-document [role='alert']",
      text:
        "Der Office-Vorgang ist noch nicht bestätigt. Dieselbe Anfrage erneut senden, um den Ausgang zu prüfen.",
    )
    expect(find('.nextcloud-office-document input[name="file_name"]').value).to eq(
      "Fehler.docx",
    )
    expect(page).to have_button("Dokument erstellen", disabled: false)
    expect(composer.composer_input.value).not_to include("cloud.example.com/s/")
  end

  it "keeps the dialog open after an uncertain share result and completes on retry" do
    stub_office_nextcloud(share_failures: 1)
    sign_in(user)
    visit "/latest"
    find("#create-topic").click
    composer.fill_title("Retry document")
    find(".toolbar-menu__options-trigger").click
    find("button[data-name='nextcloud-office-docx']").click
    find('.nextcloud-office-document input[name="file_name"]').fill_in(
      with: "Retry.docx",
    )
    find('.nextcloud-office-document button[type="submit"]').click

    expect(page).to have_css(".nextcloud-office-document .alert-error", text: "not yet confirmed")
    expect(page).to have_css(".nextcloud-office-document")
    expect(composer.composer_input.value).not_to include("https://cloud.example.com/s/")
    expect(@office_files.size).to eq(1)

    find('.nextcloud-office-document button[type="submit"]').click

    expect(page).to have_no_css(".nextcloud-office-document")
    expect(composer).to have_value(%r{\[Retry\.docx\]\(https://cloud\.example\.com/s/})
    expect(@office_files.size).to eq(1)
    expect(@office_shares.values.flatten.size).to eq(1)
  end
end
