# frozen_string_literal: true

DiscourseNextcloudOffice::Engine.routes.draw do
  scope defaults: { format: :json } do
    post "documents" => "operations#create_document"
    post "transfers" => "operations#create_transfer"
    get "operations/:operation_key" => "operations#show"
  end
end

Discourse::Application.routes.draw do
  mount ::DiscourseNextcloudOffice::Engine, at: "/nextcloud-office"
end
