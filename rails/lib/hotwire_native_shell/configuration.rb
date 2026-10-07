# frozen_string_literal: true

module HotwireNativeShell
  class Configuration
    attr_accessor :name, :base_url, :title_suffix,
                  :push_enabled, :push_topics,
                  :sign_in_with_apple, :account_deletion_path,
                  :signed_in, :owner, :signed_out_allowed,
                  :redirect_native_root

    attr_reader :signed_out_start_path, :signed_in_start_path,
                :signed_out_allowed_paths, :signed_out_allowed_controllers

    def initialize
      @name = "app"
      @base_url = nil
      @title_suffix = nil
      @signed_out_start_path = "/"
      @signed_in_start_path = "/"
      @bridges = Contract::BRIDGE_KEYS.to_h { |key| [ key, false ] }
      @push_enabled = false
      @push_topics = []
      @signed_out_tabs = []
      @signed_in_tabs = []
      @menu_items = []
      @path_rules = nil
      @sign_in_with_apple = false
      @account_deletion_path = nil
      @signed_in = -> { respond_to?(:user_signed_in?) && user_signed_in? }
      @owner = -> { request.env["warden"].respond_to?(:user) ? request.env["warden"].user : nil }
      @signed_out_allowed_paths = []
      @signed_out_allowed_controllers = []
      @signed_out_allowed = nil
      @redirect_native_root = true
    end

    def bridges
      @bridges.dup
    end

    def bridges=(values)
      incoming = values || {}
      @bridges = Contract::BRIDGE_KEYS.to_h do |key|
        [ key, !!(incoming[key] || incoming[key.to_sym]) ]
      end
    end

    def signed_out_start_path=(value)
      @signed_out_start_path = value
    end

    def signed_in_start_path=(value)
      @signed_in_start_path = value
    end

    def signed_out_allowed_paths=(values)
      @signed_out_allowed_paths = Array(values).map(&:to_s)
    end

    def signed_out_allowed_controllers=(values)
      @signed_out_allowed_controllers = Array(values).map(&:to_s)
    end

    def push_topics=(values)
      @push_topics = Array(values).map(&:to_s)
    end

    # +auth+ is :signed_out (also published on GET /native/config), :signed_in
    # (page bridge only), or :both.
    def tab(id, auth:, title:, path: nil, icon: "home", titles: nil, sf_symbol: nil, android_icon: nil, url: nil, active: nil)
      auths = case auth.to_sym
      when :both then %i[signed_out signed_in]
      when :signed_out, :signed_in then [ auth.to_sym ]
      else raise ArgumentError, "tab auth must be signed_out, signed_in, or both"
      end

      auths.each do |which|
        list = tabs_for_auth(which)
        raise ArgumentError, "at most #{Contract::MAX_TABS} #{which} tabs" if list.size >= Contract::MAX_TABS
        raise ArgumentError, "duplicate #{which} tab id #{id}" if list.any? { |tab| tab.id == id.to_s }

        list << Tab.new(
          id: id,
          title: title,
          path: path || path_from_url(url),
          auth: which,
          icon: icon,
          titles: titles,
          sf_symbol: sf_symbol,
          android_icon: android_icon,
          url: url,
          active: active
        )
      end
    end

    def menu_item(title, path, auth: :signed_in, method: nil)
      @menu_items << MenuItem.new(title: title, path: path, auth: auth, method: method)
    end

    def path_rule(patterns, context:, pull_to_refresh:, uri: nil)
      @path_rules ||= []
      @path_rules << {
        patterns: Array(patterns).map(&:to_s),
        context: context.to_s,
        pull_to_refresh: !!pull_to_refresh,
        uri: uri
      }
    end

    def signed_out_tabs
      @signed_out_tabs.dup
    end

    def signed_in_tabs
      @signed_in_tabs.dup
    end

    def menu_items_for(signed_in)
      @menu_items.select { |item| item.visible?(signed_in) }.map(&:as_hash)
    end

    def path_rules
      @path_rules || Contract::DEFAULT_PATH_RULES
    end

    def bridge_tabs(signed_in:, request:)
      source = (signed_in ? @signed_in_tabs : @signed_out_tabs).first(Contract::MAX_TABS)
      chosen = choose_active(source, request)
      source.map do |tab|
        tab.bridge_attributes(base_url: resolve_base_url(request), active: tab.equal?(chosen))
      end
    end

    def resolve_base_url(request = nil)
      value = resolve(@base_url, request).to_s.strip.sub(%r{/+\z}, "")
      raise HotwireNativeShell::ConfigurationError, "config.base_url is blank" if value.empty?

      value
    end

    def resolve_signed_out_start_path(request = nil)
      resolve(@signed_out_start_path, request).presence || "/"
    end

    def resolve_signed_in_start_path(request = nil)
      resolve(@signed_in_start_path, request).presence || "/"
    end

    def signed_out_request_allowed?(controller)
      path = controller.request.path.to_s
      start = resolve_signed_out_start_path(controller.request)
      return true if path == start || (start != "/" && path == "#{start}/")
      return true if @signed_out_allowed_paths.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }
      return true if @signed_out_allowed_controllers.include?(controller.controller_path)
      return true if controller.respond_to?(:devise_controller?, true) && controller.devise_controller?
      return true if controller.controller_path.start_with?("hotwire_native_shell/")

      @signed_out_allowed && controller.instance_exec(&@signed_out_allowed)
    end

    def resolve(value, request = nil)
      return value unless value.respond_to?(:call)

      arity = value.arity
      if arity == 0
        value.call
      elsif arity == 1
        value.call(request)
      else
        value.call
      end
    end

    private

    def tabs_for_auth(auth)
      auth == :signed_in ? @signed_in_tabs : @signed_out_tabs
    end

    def path_from_url(url)
      return "/" if url.nil?

      URI.parse(url.to_s).path.presence || "/"
    rescue URI::InvalidURIError
      "/"
    end

    def choose_active(tabs, request)
      if tabs.any?(&:active_proc)
        return tabs.find { |tab| tab.active_proc && tab.active_proc.call(request) }
      end

      tabs.select { |tab| tab.matches_request?(request) }.max_by { |tab| tab.path.length }
    end
  end

  class ConfigurationError < StandardError; end
end
