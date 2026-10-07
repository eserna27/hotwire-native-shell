# frozen_string_literal: true

require "test_helper"

class ShellRequestTest < ActionDispatch::IntegrationTest
  test "native config and path configuration are public json" do
    get native_config_path, headers: { "Accept" => "application/json", "User-Agent" => "curl/8.5.0" }

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal "itsjustmy", response.parsed_body["name"]
    assert_equal "/users/sign_in", response.parsed_body["start_path"]
    assert_equal [], response.parsed_body["tabs"]

    get android_v1_configuration_path
    assert_response :success
    android = response.parsed_body

    get ios_v1_configuration_path
    assert_response :success
    assert_equal android["rules"].map { |rule| rule["patterns"] }, response.parsed_body["rules"].map { |rule| rule["patterns"] }
    assert_nil response.parsed_body["rules"].first["properties"]["uri"]
    assert_equal "hotwire://fragment/web", android["rules"].first["properties"]["uri"]
  end

  test "browser chrome is unchanged" do
    get chrome_path, headers: { "User-Agent" => "Mozilla/5.0" }

    assert_response :success
    assert_includes response.body, "Hello | itsjustmy.blog"
    assert_select "[data-controller='bridge--tabs']", count: 0
    assert_select "[data-controller='bridge--share']", count: 0
    assert_includes response.body, "oauth-allowed"
    assert_select "a", text: "Delete account", count: 0
  end

  test "turbo native alone is not the shell" do
    get chrome_path, headers: { "User-Agent" => "Turbo Native iOS" }

    assert_includes response.body, "Hello | itsjustmy.blog"
    assert_select "[data-controller='bridge--tabs']", count: 0
  end

  test "native chrome emits tabs, share, and hides third-party login" do
    HotwireNativeShell.config.tab :home, auth: :signed_in, title: "Inicio", titles: { es: "Inicio", en: "Home" }, path: "/chrome", icon: "home"
    HotwireNativeShell.config.tab :posts, auth: :signed_in, title: "Posts", path: "/dashboard/posts", icon: "posts"
    HotwireNativeShell.config.menu_item "Sign out", "/users/sign_out", method: :delete, auth: :signed_in
    HotwireNativeShell.config.menu_item "Sign in", "/users/sign_in", auth: :signed_out
    user = User.create!(email: "writer@example.com")
    post test_session_path, params: { user_id: user.id }

    get chrome_path, headers: { "User-Agent" => native_user_agent }

    assert_response :success
    assert_select "title", text: "Hello"
    assert_select "nav[data-controller='bridge--tabs']"
    assert_select "a[data-bridge--tabs-target='tab'][data-bridge-id='home'][data-bridge-active='true'][data-bridge-icon='home'][data-bridge-path='/chrome']", text: "Home"
    assert_select "a[data-bridge-id='posts'][data-bridge-icon='posts']"
    assert_select "[data-controller='menu bridge--menu']"
    assert_select "button[data-controller='bridge--overflow-menu'][data-bridge-title='Options']"
    assert_select "a[data-bridge--menu-target='item'][href='/users/sign_out'][data-turbo-method='delete']", text: "Sign out"
    assert_select "a[href='/users/sign_in']", count: 0
    assert_select "meta[data-controller='bridge--share'][data-bridge-url='https://itsjustmy.blog/posts/1'][data-bridge-title='Hello']"
    assert_select "[data-controller='bridge--notification-token'][data-bridge-url='/native/device_tokens']"
    assert_select "button[data-controller='bridge--haptic'][data-bridge-feedback='success']", text: "Saved"
    assert_select "a[href='/users/deletion']", text: "Delete account"
    assert_not_includes response.body, "oauth-allowed"
  end

  test "native menu helper matches overflow markup" do
    HotwireNativeShell.config.menu_item "Edit", "/edit", auth: :signed_out

    get chrome_path(menu: "menu"), headers: { "User-Agent" => native_user_agent }

    assert_select "[data-controller='menu bridge--menu']"
    assert_select "a[data-bridge--menu-target='item'][href='/edit']", text: "Edit"
  end

  test "signed-out native page sends an empty tab list" do
    HotwireNativeShell.config.tab :home, auth: :signed_in, title: "Home", path: "/dashboard", icon: "home"

    get chrome_path, headers: { "User-Agent" => native_user_agent }

    assert_select "nav[data-controller='bridge--tabs']"
    assert_select "nav[data-controller='bridge--tabs'] a", count: 0
  end

  test "spanish locale uses the titles map" do
    HotwireNativeShell.config.tab :home, auth: :signed_out, title: "Inicio", titles: { es: "Inicio", en: "Home" }, path: "/chrome", icon: "home"

    I18n.with_locale(:es) do
      get chrome_path, headers: { "User-Agent" => native_user_agent }
    end

    assert_select "a[data-bridge-id='home'][data-bridge-title='Inicio']", text: "Inicio"
  end
end
