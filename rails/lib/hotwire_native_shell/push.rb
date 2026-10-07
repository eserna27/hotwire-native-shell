# frozen_string_literal: true

require "hotwire_native_shell/push/jwt"
require "hotwire_native_shell/push/credentials"
require "hotwire_native_shell/push/http"
require "hotwire_native_shell/push/apns"
require "hotwire_native_shell/push/fcm"

module HotwireNativeShell
  module Push
    class DeliveryError < StandardError; end

    module_function

    # +token+ is a DeviceToken record, or a raw token string with +provider:+.
    def deliver(token, title:, body:, data: {}, provider: nil)
      record = token.is_a?(HotwireNativeShell::DeviceToken) ? token : nil
      provider_name = (record ? record.provider : provider).to_s
      raw = record ? record.token : token.to_s
      case provider_name
      when "apns"
        Apns.new.deliver(token: raw, title: title, body: body, data: data, device_token: record)
      when "fcm"
        Fcm.new.deliver(token: raw, title: title, body: body, data: data, device_token: record)
      else
        raise DeliveryError, "provider must be apns or fcm"
      end
    end

    def deliver_to_owner(owner, title:, body:, data: {})
      HotwireNativeShell::DeviceToken.where(owner: owner).find_each do |record|
        deliver(record, title: title, body: body, data: data)
      end
    end

    # FCM topic send. The shell records push.topics and does not subscribe yet.
    # This reaches devices only after a real FCM client subscribes to +topic+.
    def deliver_topic(topic, title:, body:, data: {})
      Fcm.new.deliver_topic(topic, title: title, body: body, data: data)
    end
  end
end
