# frozen_string_literal: true

module HotwireNativeShell
  module PathConfiguration
    module_function

    # Android reads `uri`. iOS ignores it, so the iOS document omits the key.
    def document(config, platform:)
      rules = config.path_rules.map do |rule|
        properties = {
          "context" => rule[:context] || rule["context"],
          "pull_to_refresh_enabled" => !!(rule.key?(:pull_to_refresh) ? rule[:pull_to_refresh] : rule["pull_to_refresh"])
        }
        if platform.to_sym == :android
          uri = rule[:uri] || rule["uri"] || default_uri(properties["context"])
          properties = {
            "context" => properties["context"],
            "uri" => uri,
            "pull_to_refresh_enabled" => properties["pull_to_refresh_enabled"]
          }
        end
        { "patterns" => Array(rule[:patterns] || rule["patterns"]), "properties" => properties }
      end

      { "settings" => {}, "rules" => rules }
    end

    def default_uri(context)
      context.to_s == "modal" ? "hotwire://fragment/web/modal/sheet" : "hotwire://fragment/web"
    end
  end
end
