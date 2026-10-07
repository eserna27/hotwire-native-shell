# frozen_string_literal: true

module HotwireNativeShell
  # Field names shared with the Android and iOS shells.
  # script/check_contract.py reads this file. Keep the lists in this order.
  module Contract
    BRIDGE_KEYS = %w[
      notification_token
      share
      haptic
      camera
      biometric
      clipboard
      file_download
    ].freeze

    # JSON key => Stimulus `static component` value.
    COMPONENT_NAMES = {
      "notification_token" => "notification-token",
      "share" => "share",
      "haptic" => "haptic",
      "camera" => "camera",
      "biometric" => "biometric",
      "clipboard" => "clipboard",
      "file_download" => "file-download"
    }.freeze

    # Always registered by the shell. They are not keys in /native/config.
    ALWAYS_ON_COMPONENTS = %w[menu overflow-menu tabs].freeze

    PLACEHOLDER_TOKEN = "placeholder-not-a-device-token"
    PLACEHOLDER_PROVIDER = "placeholder"

    MAX_TABS = 5

    # Shared icon catalog. Unknown names fall back to home inside the shell.
    ICON_NAMES = %w[home posts search profile info].freeze

    TAB_ID = /\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}\z/

    DEFAULT_PATH_RULES = [
      {
        patterns: [ ".*" ],
        context: "default",
        pull_to_refresh: true,
        uri: "hotwire://fragment/web"
      },
      {
        patterns: [ "/new$", "/edit$" ],
        context: "modal",
        pull_to_refresh: false,
        uri: "hotwire://fragment/web/modal/sheet"
      }
    ].freeze
  end
end
