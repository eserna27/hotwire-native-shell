# frozen_string_literal: true

require "hotwire_native_shell/version"
require "hotwire_native_shell/contract"
require "hotwire_native_shell/title"
require "hotwire_native_shell/tab"
require "hotwire_native_shell/menu_item"
require "hotwire_native_shell/configuration"
require "hotwire_native_shell/payload"
require "hotwire_native_shell/path_configuration"
require "hotwire_native_shell/controller_methods"
require "hotwire_native_shell/native_helper"
require "hotwire_native_shell/native_entry"
require "hotwire_native_shell/push"

module HotwireNativeShell
  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    def reset!
      @config = Configuration.new
    end

    def payload(request = nil)
      Payload.build(config, request)
    end

    def path_configuration(platform)
      PathConfiguration.document(config, platform: platform)
    end
  end
end

require "hotwire_native_shell/engine" if defined?(Rails::Engine)
require "hotwire_native_shell/routes" if defined?(ActionDispatch::Routing::Mapper)
