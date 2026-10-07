# frozen_string_literal: true

module HotwireNativeShell
  # GET /native/config — public shell metadata. No auth, no user data.
  class ConfigsController < ActionController::Base
    def show
      render json: HotwireNativeShell.payload(request)
    end
  end
end
