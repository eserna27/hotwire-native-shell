# frozen_string_literal: true

module HotwireNativeShell
  # Opt-in auth-first navigation for Hotwire Native requests.
  #
  #   class ApplicationController < ActionController::Base
  #     include HotwireNativeShell::NativeEntry
  #   end
  #
  # Signed-out HTML visits go to +signed_out_start_path+ unless the path or
  # controller is allowed. Signed-in visits to "/" go to +signed_in_start_path+.
  # The website (any user agent without "Hotwire Native") is left alone.
  module NativeEntry
    extend ActiveSupport::Concern

    included do
      before_action :apply_native_entry_redirect
    end

    def apply_native_entry_redirect
      return unless hotwire_native_app?
      return unless request.get? || request.head?
      return unless request.format.html? || request.format.turbo_stream?

      if native_signed_in?
        redirect_native_signed_in_root
      else
        redirect_native_signed_out
      end
    end

    private

    def redirect_native_signed_in_root
      return unless HotwireNativeShell.config.redirect_native_root

      destination = HotwireNativeShell.config.resolve_signed_in_start_path(request)
      return if destination.blank? || destination == "/"
      return unless request.path == "/"

      redirect_to destination
    end

    def redirect_native_signed_out
      return if HotwireNativeShell.config.signed_out_request_allowed?(self)

      destination = HotwireNativeShell.config.resolve_signed_out_start_path(request)
      return if destination.blank? || request.path == destination

      redirect_to destination
    end
  end
end
