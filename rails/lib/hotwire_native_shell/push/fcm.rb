# frozen_string_literal: true

require "json"
require "openssl"

module HotwireNativeShell
  module Push
    class Fcm
      TOKEN_URL = "https://oauth2.googleapis.com/token"
      SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

      def initialize(credentials: Credentials.new, http: Http)
        @credentials = credentials
        @http = http
      end

      def deliver(token:, title:, body:, data: {}, device_token: nil)
        post_message({ "token" => token }, title: title, body: body, data: data, device_token: device_token)
      end

      def deliver_topic(topic, title:, body:, data: {})
        post_message({ "topic" => topic }, title: title, body: body, data: data, device_token: nil)
      end

      def self.assertion_for(account, now: Time.now.to_i)
        Jwt.encode(
          {
            "iss" => account["client_email"],
            "scope" => SCOPE,
            "aud" => TOKEN_URL,
            "iat" => now,
            "exp" => now + 3600
          },
          account["private_key"],
          alg: "RS256"
        )
      end

      private

      def post_message(target, title:, body:, data:, device_token:)
        account = @credentials.require_fcm!
        access = access_token(account)
        message = target.merge("notification" => { "title" => title.to_s, "body" => body.to_s })
        string_data = stringify_data(data)
        message["data"] = string_data if string_data.any?
        response = @http.post_json(
          "https://fcm.googleapis.com/v1/projects/#{account["project_id"]}/messages:send",
          { "message" => message },
          headers: { "authorization" => "Bearer #{access}" }
        )
        forget(device_token) if unregistered?(response)
        return response if response.status == 200 || unregistered?(response)

        raise DeliveryError, "FCM responded #{response.status}"
      end

      def access_token(account)
        assertion = self.class.assertion_for(account)
        response = @http.post_form(
          TOKEN_URL,
          { "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion" => assertion }
        )
        raise DeliveryError, "FCM token endpoint responded #{response.status}" unless response.status == 200

        JSON.parse(response.body).fetch("access_token")
      end

      def stringify_data(data)
        data.each_with_object({}) { |(key, value), map| map[key.to_s] = value.to_s }
      end

      def unregistered?(response)
        return true if response.status == 404

        response.body.to_s.include?("UNREGISTERED")
      end

      def forget(device_token)
        device_token.destroy if device_token.respond_to?(:destroy) && device_token.respond_to?(:destroyed?) && !device_token.destroyed?
      end
    end
  end
end
