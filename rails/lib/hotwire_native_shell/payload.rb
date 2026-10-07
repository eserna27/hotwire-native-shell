# frozen_string_literal: true

module HotwireNativeShell
  module Payload
    module_function

    # Public cold-start document. The shell caches this before it can trust a
    # session, so start_path and tabs are the signed-out values.
    def build(config, request = nil)
      {
        "name" => config.name.to_s,
        "base_url" => config.resolve_base_url(request),
        "start_path" => config.resolve_signed_out_start_path(request),
        "tabs" => config.signed_out_tabs.first(Contract::MAX_TABS).map(&:config_json),
        "bridges" => config.bridges.transform_keys(&:to_s),
        "push" => {
          "enabled" => !!config.push_enabled,
          "topics" => Array(config.push_topics).map(&:to_s)
        }
      }
    end
  end
end
