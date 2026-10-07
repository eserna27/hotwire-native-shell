# frozen_string_literal: true

module HotwireNativeShell
  # Hotwire path configuration, separate from GET /native/config.
  class ConfigurationsController < ActionController::Base
    def android
      render json: HotwireNativeShell.path_configuration(:android)
    end

    def ios
      render json: HotwireNativeShell.path_configuration(:ios)
    end
  end
end
