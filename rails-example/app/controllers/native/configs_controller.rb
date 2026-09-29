# frozen_string_literal: true

module Native
  # GET /native/config
  #
  # Copy into the client app. Point `payload` at that app's own JSON or
  # a small Ruby hash. Keep the keys stable; see docs/CONTRACT.md.
  class ConfigsController < ApplicationController
    def show
      render json: NativeConfig.payload
    end
  end
end
