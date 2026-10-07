# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)
require "hotwire_native_shell-rails"

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.load_defaults 8.0
    config.eager_load = false
    config.secret_key_base = "dummy-secret-key-base-for-hotwire-native-shell-tests-only"
    config.api_only = false
    config.active_record.maintain_test_schema = false
    config.logger = ActiveSupport::Logger.new(nil)
    config.i18n.available_locales = [ :en, :es ]
    config.i18n.default_locale = :en
  end
end
