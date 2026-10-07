# frozen_string_literal: true

require "base64"
require "json"
require "openssl"

module HotwireNativeShell
  module Push
    module Jwt
      module_function

      def encode(payload, key, alg:, kid: nil)
        header = { "alg" => alg, "typ" => "JWT" }
        header["kid"] = kid if kid
        segments = [ header, payload ].map { |part| b64(JSON.generate(part)) }
        signing_input = segments.join(".")
        "#{signing_input}.#{b64(sign(alg, key, signing_input))}"
      end

      def b64(data)
        Base64.urlsafe_encode64(data, padding: false)
      end

      def sign(alg, key, data)
        case alg
        when "ES256"
          pkey = key.is_a?(OpenSSL::PKey::PKey) ? key : OpenSSL::PKey::EC.new(key)
          der_to_raw(pkey.sign("SHA256", data))
        when "RS256"
          pkey = key.is_a?(OpenSSL::PKey::PKey) ? key : OpenSSL::PKey::RSA.new(key)
          pkey.sign("SHA256", data)
        else
          raise ArgumentError, "unsupported JWT alg #{alg}"
        end
      end

      def der_to_raw(der)
        seq = OpenSSL::ASN1.decode(der)
        fixed_width(seq.value[0].value, 32) + fixed_width(seq.value[1].value, 32)
      end

      def fixed_width(int, size)
        [ format("%0#{size * 2}x", int.to_i) ].pack("H*")
      end
    end
  end
end
