# frozen_string_literal: true

require "test_helper"

class PathConfigurationTest < ActiveSupport::TestCase
  test "default rules match the shell bundles" do
    root = Pathname.new(File.expand_path("../..", __dir__))
    android = JSON.parse(File.read(root.join("android/app/src/main/assets/json/path-configuration.json")))
    ios = JSON.parse(File.read(root.join("ios/HotwireNativeShell/path-configuration.json")))

    assert_equal android, HotwireNativeShell.path_configuration(:android)
    assert_equal ios, HotwireNativeShell.path_configuration(:ios)
  end

  test "custom rules still omit uri on ios" do
    HotwireNativeShell.config.path_rule [ "/posts/new$" ], context: "modal", pull_to_refresh: false

    ios = HotwireNativeShell.path_configuration(:ios)
    android = HotwireNativeShell.path_configuration(:android)

    assert_equal [ "/posts/new$" ], ios["rules"].last["patterns"]
    assert_nil ios["rules"].last["properties"]["uri"]
    assert_equal "hotwire://fragment/web/modal/sheet", android["rules"].last["properties"]["uri"]
  end
end
