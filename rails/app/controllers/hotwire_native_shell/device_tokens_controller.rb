# frozen_string_literal: true

module HotwireNativeShell
  # POST /native/device_tokens
  #
  # Body matches the shell's notification-token reply, plus the web platform:
  #   { "token": "...", "provider": "fcm" | "apns", "platform": "android" | "ios" }
  # The placeholder token is accepted and not stored.
  class DeviceTokensController < ActionController::Base
    protect_from_forgery with: :exception

    def create
      if DeviceToken.placeholder?(params[:token], params[:provider])
        render json: { status: "ignored" }
        return
      end

      DeviceToken.register!(
        token: params[:token],
        provider: params[:provider],
        platform: params[:platform],
        owner: current_owner
      )
      render json: { status: "ok" }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { error: error.record.errors.full_messages }, status: :unprocessable_entity
    end

    def destroy
      record = DeviceToken.find_by(token: params[:token].to_s)
      head :no_content and return if record.nil?

      owner = current_owner
      if record.owner_id.present? && owner != record.owner
        head :forbidden
        return
      end

      record.destroy!
      head :no_content
    end

    private

    def current_owner
      body = HotwireNativeShell.config.owner
      return if body.nil?

      instance_exec(&body)
    end
  end
end
