# frozen_string_literal: true

module HotwireNativeShell
  module ControllerMethods
    extend ActiveSupport::Concern

    included do
      helper_method :hotwire_native_app?, :native_signed_in?, :native_document_title,
                    :native_render_web_nav?, :native_oauth_allowed?, :native_signed_out_flow?,
                    :native_start_path if respond_to?(:helper_method)
    end

    def hotwire_native_app?
      request.user_agent.to_s.match?(/Hotwire Native/)
    end

    def native_signed_in?
      predicate = HotwireNativeShell.config.signed_in
      return false unless predicate

      !!instance_exec(&predicate)
    end

    def native_document_title(title)
      text = title.to_s
      return text unless hotwire_native_app?

      Title.without_suffix(text, HotwireNativeShell.config.title_suffix)
    end

    def native_render_web_nav?
      !hotwire_native_app?
    end

    # Guideline 4.8: third-party login in the native app stays off until
    # Sign in with Apple is configured.
    def native_oauth_allowed?
      return true unless hotwire_native_app?

      !!HotwireNativeShell.config.sign_in_with_apple
    end

    def native_signed_out_flow?
      hotwire_native_app? && !native_signed_in?
    end

    def native_start_path
      if native_signed_in?
        HotwireNativeShell.config.resolve_signed_in_start_path(request)
      else
        HotwireNativeShell.config.resolve_signed_out_start_path(request)
      end
    end
  end
end
