# frozen_string_literal: true

require "json"
require "rails/generators"

module HotwireNativeShell
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)
    desc "Install routes, initializer, and bridge controllers for the Hotwire Native shell"

    def copy_initializer
      template "hotwire_native_shell.rb", "config/initializers/hotwire_native_shell.rb"
    end

    def add_routes
      route_file = File.join(destination_root, "config/routes.rb")
      return unless File.exist?(route_file)
      return if File.read(route_file).include?("hotwire_native_shell")

      route "hotwire_native_shell"
    end

    def copy_bridge_controllers
      Dir.glob(Engine.root.join("app/javascript/hotwire_native_shell/bridge/*.js")).sort.each do |source|
        copy_file source, "app/javascript/controllers/bridge/#{File.basename(source)}"
      end
    end

    def copy_menu_controller
      target = "app/javascript/controllers/menu_controller.js"
      return if File.exist?(File.join(destination_root, target))

      copy_file Engine.root.join("app/javascript/hotwire_native_shell/menu_controller.js").to_s, target
    end

    def copy_tabs_partial
      copy_file "_native_tabs.html.erb", "app/views/shared/_native_tabs.html.erb"
    end

    def pin_bridge_package
      path = File.join(destination_root, "config/importmap.rb")
      return unless File.exist?(path)
      return if File.read(path).include?("@hotwired/hotwire-native-bridge")

      append_to_file "config/importmap.rb", <<~RUBY

        pin "@hotwired/hotwire-native-bridge", to: "https://cdn.jsdelivr.net/npm/@hotwired/hotwire-native-bridge@1.2.2/dist/hotwire-native-bridge.js"
      RUBY
    end

    def add_npm_dependency
      path = File.join(destination_root, "package.json")
      return unless File.exist?(path)

      json = JSON.parse(File.read(path))
      json["dependencies"] ||= {}
      return if json["dependencies"].key?("@hotwired/hotwire-native-bridge")

      json["dependencies"]["@hotwired/hotwire-native-bridge"] = "^1.2.2"
      File.write(path, JSON.pretty_generate(json) + "\n")
    end

    def ignore_push_secrets
      path = File.join(destination_root, ".gitignore")
      return unless File.exist?(path)

      marker = "AuthKey_*.p8"
      return if File.read(path).include?(marker)

      append_to_file ".gitignore", <<~IGNORE

        # Hotwire Native push credentials. Do not commit.
        AuthKey_*.p8
        *-firebase-adminsdk-*.json
      IGNORE
    end

    def install_device_tokens
      invoke "hotwire_native_shell:device_tokens"
    end

    def instructions
      say <<~TEXT

        Add <%= render "shared/native_tabs" %> and <%= stylesheet_link_tag "hotwire_native_shell" %> to the layout.
        Call native_share, native_overflow_menu, and native_notification_token only on the pages that need them.
        For an auth-first shell, include HotwireNativeShell::NativeEntry in ApplicationController.
        Upload APNs and FCM secrets to credentials or ENV. See rails/README.md.
        Then run bin/rails db:migrate.
      TEXT
    end
  end
end
