# frozen_string_literal: true

require "test_helper"

class ContractDriftTest < ActiveSupport::TestCase
  test "bridge keys and component names match the shell contract" do
    root = Pathname.new(File.expand_path("../..", __dir__))
    flavor = JSON.parse(File.read(root.join("flavors/itsjustmy/assets/native/config.json")))

    assert_equal flavor["bridges"].keys, HotwireNativeShell::Contract::BRIDGE_KEYS
    assert_equal 5, HotwireNativeShell::Contract::MAX_TABS
    assert_equal "placeholder-not-a-device-token", HotwireNativeShell::Contract::PLACEHOLDER_TOKEN

    HotwireNativeShell::Contract::COMPONENT_NAMES.each do |key, component|
      assert_includes HotwireNativeShell::Contract::BRIDGE_KEYS, key
      if %w[notification-token share haptic].include?(component)
        source = File.read(root.join("rails/app/javascript/hotwire_native_shell/bridge/#{component.tr("-", "_")}_controller.js"))
        assert_includes source, %(static component = "#{component}")
      end
    end

    %w[menu overflow-menu tabs].each do |component|
      file = component == "overflow-menu" ? "overflow_menu_controller.js" : "#{component}_controller.js"
      source = File.read(root.join("rails/app/javascript/hotwire_native_shell/bridge/#{file}"))
      assert_includes source, %(static component = "#{component}")
    end

    token = File.read(root.join("rails/app/javascript/hotwire_native_shell/bridge/notification_token_controller.js"))
    assert_includes token, "placeholder-not-a-device-token"
    assert_includes token, "/native/device_tokens"
    assert_includes token, "provider"

    registrar = File.read(root.join("android/app/src/main/kotlin/dev/hotwire/nativeshell/bridge/BridgeRegistrar.kt"))
    HotwireNativeShell::Contract::ALWAYS_ON_COMPONENTS.each do |component|
      assert_includes registrar, %("#{component}")
    end
  end

  test "title suffix stripping leaves the page name" do
    assert_equal "Hello", HotwireNativeShell::Title.without_suffix("Hello | itsjustmy.blog", "itsjustmy.blog")
    assert_equal "Hello", HotwireNativeShell::Title.without_suffix("Hello|itsjustmy.blog", "itsjustmy.blog")
    assert_equal "itsjustmy.blog", HotwireNativeShell::Title.without_suffix(" | itsjustmy.blog", "itsjustmy.blog")
    assert_equal "Hello | other", HotwireNativeShell::Title.without_suffix("Hello | other", "itsjustmy.blog")
  end
end
