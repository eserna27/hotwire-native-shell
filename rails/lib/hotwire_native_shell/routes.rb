# frozen_string_literal: true

module ActionDispatch
  module Routing
    class Mapper
      # GET /native/config
      # GET /configurations/android_v1.json
      # GET /configurations/ios_v1.json
      # POST /native/device_tokens
      # DELETE /native/device_tokens
      def hotwire_native_shell
        get "native/config", to: "hotwire_native_shell/configs#show", as: :native_config
        post "native/device_tokens", to: "hotwire_native_shell/device_tokens#create", as: :native_device_tokens
        delete "native/device_tokens", to: "hotwire_native_shell/device_tokens#destroy"
        get "configurations/android_v1.json", to: "hotwire_native_shell/configurations#android", as: :android_v1_configuration
        get "configurations/ios_v1.json", to: "hotwire_native_shell/configurations#ios", as: :ios_v1_configuration
      end
    end
  end
end
