# frozen_string_literal: true

Rails.application.routes.draw do
  hotwire_native_shell

  root to: "native_entry#root"
  get "entry", to: "native_entry#show"
  get "chrome", to: "pages#chrome"
  post "test_session", to: "test_session#create"
end
