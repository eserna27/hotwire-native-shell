# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/hotwire_native_shell/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests HotwireNativeShell::InstallGenerator
  destination File.expand_path("../tmp/generators", __dir__)
  setup :prepare_destination

  setup do
    FileUtils.mkdir_p File.join(destination_root, "config")
    File.write File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n"
    File.write File.join(destination_root, "config/importmap.rb"), "pin \"application\"\n"
    File.write File.join(destination_root, "package.json"), %({"dependencies":{}}\n)
    File.write File.join(destination_root, ".gitignore"), "log/\n"
  end

  test "install writes the contract surface" do
    run_generator

    assert_file "config/initializers/hotwire_native_shell.rb" do |content|
      assert_match "HotwireNativeShell.configure", content
      assert_match "signed_out_start_path", content
      assert_match "signed_in_start_path", content
      assert_match "sign_in_with_apple", content
      assert_match "account_deletion_path", content
    end
    assert_file "config/routes.rb" do |content|
      assert_match(/^\s+hotwire_native_shell$/, content)
    end
    assert_file "app/javascript/controllers/bridge/tabs_controller.js" do |content|
      assert_match 'static component = "tabs"', content
    end
    assert_file "app/javascript/controllers/bridge/share_controller.js" do |content|
      assert_match 'static component = "share"', content
      assert_match "title", content
    end
    assert_file "app/javascript/controllers/bridge/notification_token_controller.js" do |content|
      assert_match "placeholder-not-a-device-token", content
      assert_match "/native/device_tokens", content
    end
    assert_file "app/javascript/controllers/menu_controller.js"
    assert_file "app/views/shared/_native_tabs.html.erb" do |content|
      assert_match "native_tabs", content
    end
    assert_file "config/importmap.rb" do |content|
      assert_match "@hotwired/hotwire-native-bridge@1.2.2", content
    end
    assert_file "package.json" do |content|
      assert_match "@hotwired/hotwire-native-bridge", content
    end
    assert_file ".gitignore" do |content|
      assert_match "AuthKey_*.p8", content
    end
    assert_migration "db/migrate/create_hotwire_native_shell_device_tokens.rb" do |content|
      assert_match "hotwire_native_shell_device_tokens", content
      assert_match "t.string :token", content
      assert_match "t.string :provider", content
    end
  end
end
