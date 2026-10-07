# frozen_string_literal: true

require "test_helper"

class PayloadTest < ActiveSupport::TestCase
  test "auth-first cold start publishes signed-out path and no tabs" do
    payload = HotwireNativeShell.payload

    assert_equal "itsjustmy", payload["name"]
    assert_equal "https://itsjustmy.blog", payload["base_url"]
    assert_equal "/users/sign_in", payload["start_path"]
    assert_equal [], payload["tabs"]
    assert_equal true, payload.dig("bridges", "notification_token")
    assert_equal true, payload.dig("bridges", "share")
    assert_equal true, payload.dig("bridges", "haptic")
    assert_equal false, payload.dig("bridges", "camera")
    assert_equal false, payload.dig("bridges", "file_download")
    assert_equal [ "posts" ], payload.dig("push", "topics")
    assert_equal HotwireNativeShell::Contract::BRIDGE_KEYS, payload["bridges"].keys
  end

  test "builder matches the itsjustmy flavor document" do
    HotwireNativeShell.reset!
    HotwireNativeShell.configure do |config|
      config.name = "itsjustmy"
      config.base_url = "https://itsjustmy.blog"
      config.signed_out_start_path = "/"
      config.bridges = { notification_token: true, share: true, haptic: true }
      config.push_enabled = true
      config.push_topics = [ "posts" ]
      config.tab :home, auth: :signed_out, title: "Inicio", titles: { es: "Inicio", en: "Home" }, path: "/", icon: "home"
      config.tab :about, auth: :signed_out, title: "Acerca", titles: { es: "Acerca", en: "About" }, path: "/acerca", icon: "info", sf_symbol: "info.circle"
      config.tab :sign_in, auth: :signed_out, title: "Entrar", titles: { es: "Entrar", en: "Sign in" }, path: "/users/sign_in", icon: "profile", android_icon: "ic_tab_profile"
    end

    expected = JSON.parse(File.read(shell_root.join("flavors/itsjustmy/assets/native/config.json")))
    assert_equal expected, HotwireNativeShell.payload
  end

  test "signed-in tabs are not part of the cold-start document" do
    HotwireNativeShell.config.tab :home, auth: :signed_in, title: "Inicio", path: "/dashboard", icon: "home"

    assert_equal [], HotwireNativeShell.payload["tabs"]
    assert_equal [ "home" ], HotwireNativeShell.config.signed_in_tabs.map(&:id)
  end

  test "a sixth tab is rejected" do
    5.times do |index|
      HotwireNativeShell.config.tab "t#{index}", auth: :signed_in, title: "T", path: "/#{index}", icon: "home"
    end

    assert_raises(ArgumentError) do
      HotwireNativeShell.config.tab :extra, auth: :signed_in, title: "Extra", path: "/extra", icon: "home"
    end
  end

  test "tab ids follow the shell rule" do
    assert_raises(ArgumentError) do
      HotwireNativeShell.config.tab "bad id", auth: :signed_out, title: "Bad", path: "/", icon: "home"
    end
  end

  test "longest tab path wins and a foreign url does not" do
    HotwireNativeShell.config.tab :home, auth: :signed_in, title: "Home", path: "/", icon: "home"
    HotwireNativeShell.config.tab :posts, auth: :signed_in, title: "Posts", path: "/dashboard/posts", icon: "posts"
    HotwireNativeShell.config.tab :blog, auth: :signed_in, title: "Blog", path: "/", icon: "info", url: "https://other.example/", sf_symbol: "globe"
    request = Struct.new(:path, :host).new("/dashboard/posts/1", "itsjustmy.blog")

    tabs = HotwireNativeShell.config.bridge_tabs(signed_in: true, request: request)

    assert_equal true, tabs.find { |tab| tab[:id] == "posts" }[:active]
    assert_equal false, tabs.find { |tab| tab[:id] == "home" }[:active]
    assert_equal false, tabs.find { |tab| tab[:id] == "blog" }[:active]
    assert_equal "https://itsjustmy.blog/dashboard/posts", tabs.find { |tab| tab[:id] == "posts" }[:url]
    assert_equal "https://other.example/", tabs.find { |tab| tab[:id] == "blog" }[:url]
  end

  test "an active proc can leave every tab unmarked" do
    HotwireNativeShell.config.tab :home, auth: :signed_in, title: "Home", path: "/", icon: "home", active: ->(request) { request.path == "/dashboard" }
    request = Struct.new(:path, :host).new("/privacy", "itsjustmy.blog")

    tabs = HotwireNativeShell.config.bridge_tabs(signed_in: true, request: request)

    assert_equal false, tabs.first[:active]
  end

  test "blank base_url fails the document" do
    HotwireNativeShell.config.base_url = "  "

    assert_raises(HotwireNativeShell::ConfigurationError) { HotwireNativeShell.payload }
  end

  def shell_root
    Pathname.new(File.expand_path("../..", __dir__))
  end
end
