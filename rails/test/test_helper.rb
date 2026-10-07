# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require "fileutils"

FileUtils.mkdir_p File.expand_path("dummy/tmp", __dir__)
FileUtils.mkdir_p File.expand_path("dummy/log", __dir__)

require_relative "dummy/config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    setup do
      HotwireNativeShell.reset!
      apply_shell_config
    end

    def apply_shell_config
      HotwireNativeShell.configure do |config|
        config.name = "itsjustmy"
        config.base_url = "https://itsjustmy.blog"
        config.title_suffix = "itsjustmy.blog"
        config.signed_out_start_path = "/users/sign_in"
        config.signed_in_start_path = "/dashboard"
        config.bridges = { notification_token: true, share: true, haptic: true }
        config.push_enabled = true
        config.push_topics = [ "posts" ]
        config.account_deletion_path = "/users/deletion"
        config.signed_out_allowed_paths = [ "/entry" ]
        config.owner = -> { User.find_by(id: session[:user_id]) if session[:user_id] }
      end
    end

    def native_user_agent
      "itsjustmy; Hotwire Native iOS; Turbo Native iOS; bridge-components: [menu overflow-menu tabs notification-token share haptic];"
    end
  end
end

connection = ActiveRecord::Base.connection
connection.tables.each do |table|
  next if table.start_with?("sqlite_")

  connection.drop_table(table, if_exists: true)
end
load Rails.root.join("db/schema.rb")
