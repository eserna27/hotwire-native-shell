# frozen_string_literal: true

module HotwireNativeShell
  class MenuItem
    METHODS = %w[get post patch put delete].freeze

    attr_reader :title, :path, :method, :auth

    def initialize(title:, path:, auth: :signed_in, method: nil)
      @title = title.to_s
      @path = path.to_s
      @auth = auth.to_sym
      @method = method&.to_s&.downcase.presence
      raise ArgumentError, "menu item needs a title" if @title.empty?
      raise ArgumentError, "menu item needs a path" if @path.empty?
      raise ArgumentError, "menu item method must be one of #{METHODS.join(", ")}" if @method && !METHODS.include?(@method)
      raise ArgumentError, "menu item auth must be signed_in, signed_out, or both" unless %i[signed_in signed_out both].include?(@auth)
    end

    def visible?(signed_in)
      case auth
      when :both then true
      when :signed_in then signed_in
      else !signed_in
      end
    end

    def as_hash
      hash = { title: title, href: path }
      hash[:method] = method.to_sym if method && method != "get"
      hash
    end
  end
end
