# frozen_string_literal: true

# Lines to add in the client Rails app. This file is not a bootable
# config/routes.rb on its own.
#
# Rails.application.routes.draw do
#   namespace :native do
#     resource :config, only: :show
#   end
#
#   get "configurations/android_v1.json", to: "configurations#android"
#   get "configurations/ios_v1.json", to: "configurations#ios"
# end

Rails.application.routes.draw do
  namespace :native do
    resource :config, only: :show
  end

  get "configurations/android_v1.json", to: "configurations#android"
  get "configurations/ios_v1.json", to: "configurations#ios"
end
