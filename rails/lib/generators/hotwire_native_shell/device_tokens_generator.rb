# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module HotwireNativeShell
  class DeviceTokensGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path("device_tokens/templates", __dir__)
    desc "Create the hotwire_native_shell_device_tokens migration"

    def self.next_migration_number(dirname)
      next_migration_number = current_migration_number(dirname) + 1
      ActiveRecord::Migration.next_migration_number(next_migration_number)
    end

    def copy_migration
      migration_template(
        "create_hotwire_native_shell_device_tokens.rb.tt",
        "db/migrate/create_hotwire_native_shell_device_tokens.rb"
      )
    end
  end
end
