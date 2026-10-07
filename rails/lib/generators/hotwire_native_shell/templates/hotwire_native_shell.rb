# frozen_string_literal: true

# Hotwire Native shell contract. See rails/README.md and docs/CONTRACT.md.
#
# GET /native/config publishes the signed-out start path and signed-out tabs.
# The shell caches that document before it can trust a session. Signed-in tabs
# are sent later by the native_tabs helper on each native page.
HotwireNativeShell.configure do |config|
  config.name = "myapp"
  config.base_url = "https://example.com"
  config.title_suffix = "example.com"

  config.signed_out_start_path = "/users/sign_in"
  config.signed_in_start_path = "/"

  # Cold start has no tab bar. Add signed-in tabs with config.tab.
  # config.tab :home, auth: :signed_in, title: "Home", path: "/dashboard", icon: "home"
  # config.tab :posts, auth: :signed_in, title: "Posts", path: "/dashboard/posts", icon: "posts"
  #
  # auth: :signed_out tabs are also the cold-start list on GET /native/config.
  # auth: :both publishes the tab in both places.
  # Pass active: ->(request) { request.path == "/dashboard" } to override
  # longest-prefix matching.

  # config.menu_item "Sign out", "/users/sign_out", method: :delete, auth: :signed_in

  # Flags the shell may register. Missing or false stays off.
  # menu, overflow-menu, and tabs are always registered and are not keys here.
  config.bridges = {
    notification_token: false,
    share: false,
    haptic: false,
    camera: false,
    biometric: false,
    clipboard: false,
    file_download: false
  }

  config.push_enabled = false
  config.push_topics = []

  # Guideline 4.8. Leave false, and wrap third-party login in native_oauth_allowed?,
  # until Sign in with Apple is on.
  config.sign_in_with_apple = false

  # Guideline 5.1.1(v). Set a real account-deletion path before shipping
  # an app that creates accounts. native_account_deletion_link stays blank until then.
  config.account_deletion_path = nil

  # Paths a signed-out native visitor may open (sign-in, password reset, legal).
  # config.signed_out_allowed_paths = ["/users/sign_in", "/users/sign_up", "/users/password"]
  # config.signed_out_allowed_controllers = ["legal"]

  # Include HotwireNativeShell::NativeEntry in ApplicationController to
  # redirect signed-out native HTML visits to signed_out_start_path.
end
