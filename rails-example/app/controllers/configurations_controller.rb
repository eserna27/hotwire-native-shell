# frozen_string_literal: true

# Hotwire path configuration, separate from GET /native/config.
# Android loads /configurations/android_v1.json. iOS can use the same
# document at /configurations/ios_v1.json until the rules diverge.
class ConfigurationsController < ApplicationController
  def android
    render json: NativeConfig.path_configuration
  end

  def ios
    render json: NativeConfig.path_configuration
  end
end
