# frozen_string_literal: true

require "test_helper"
require "openssl"
require "base64"

class PushTest < ActiveSupport::TestCase
  test "APNs JWT is ES256 and the request uses the device token" do
    key = OpenSSL::PKey::EC.generate("prime256v1")
    settings = {
      key_id: "KEYID12345",
      team_id: "TEAMID1234",
      bundle_id: "blog.itsjustmy.app",
      private_key: key.to_pem,
      sandbox: true
    }

    http = FakeHttp.new
    http.apns_response = HotwireNativeShell::Push::Http::Response.new(status: 200, body: "")
    credentials = Struct.new(:settings) do
      def require_apns!
        settings
      end
    end.new(settings)
    HotwireNativeShell::Push::Apns.new(credentials: credentials, http: http).deliver(
      token: "device-token",
      title: "Hola",
      body: "Nuevo post",
      data: { "post_id" => "9" }
    )
    captured = http.apns_calls.first

    assert_equal "api.sandbox.push.apple.com", captured[:host]
    assert_equal "/3/device/device-token", captured[:path]
    assert_equal "blog.itsjustmy.app", captured[:headers]["apns-topic"]
    assert_equal "alert", captured[:headers]["apns-push-type"]
    jwt = captured[:headers]["authorization"].delete_prefix("bearer ")
    header, payload, signature = jwt.split(".")
    assert_equal "ES256", JSON.parse(b64(header))["alg"]
    assert_equal "KEYID12345", JSON.parse(b64(header))["kid"]
    assert_equal "TEAMID1234", JSON.parse(b64(payload))["iss"]
    assert key.verify("SHA256", raw_to_der(b64(signature)), "#{header}.#{payload}")
    body = JSON.parse(captured[:body])
    assert_equal "Hola", body.dig("aps", "alert", "title")
    assert_equal "9", body["post_id"]
  end

  test "APNs 410 deletes the stored token" do
    record = HotwireNativeShell::DeviceToken.register!(token: "gone", provider: "apns", platform: "ios")
    http = FakeHttp.new
    http.apns_response = HotwireNativeShell::Push::Http::Response.new(status: 410, body: "")
    credentials = Object.new
    def credentials.require_apns!
      key = OpenSSL::PKey::EC.generate("prime256v1")
      { key_id: "K", team_id: "T", bundle_id: "blog.itsjustmy.app", private_key: key.to_pem, sandbox: false }
    end
    HotwireNativeShell::Push::Apns.new(credentials: credentials, http: http).deliver(
      token: record.token, title: "T", body: "B", device_token: record
    )

    assert_not HotwireNativeShell::DeviceToken.exists?(token: "gone")
  end

  test "FCM v1 posts a service-account assertion and string data" do
    rsa = OpenSSL::PKey::RSA.generate(2048)
    account = {
      "client_email" => "push@example.iam.gserviceaccount.com",
      "private_key" => rsa.to_pem,
      "project_id" => "itsjustmy",
      "token_uri" => "https://oauth2.googleapis.com/token"
    }
    http = FakeHttp.new
    http.form_response = HotwireNativeShell::Push::Http::Response.new(status: 200, body: %({"access_token":"ya29.test"}))
    http.json_response = HotwireNativeShell::Push::Http::Response.new(status: 200, body: "{}")
    credentials = Object.new
    credentials.define_singleton_method(:require_fcm!) { account }
    HotwireNativeShell::Push::Fcm.new(credentials: credentials, http: http).deliver(
      token: "fcm-token",
      title: "Hola",
      body: "Nuevo",
      data: { post_id: 9 }
    )
    calls = http.calls

    form = calls[0]
    assert_equal "https://oauth2.googleapis.com/token", form[1]
    assertion = form[2]["assertion"]
    header, payload, signature = assertion.split(".")
    assert_equal "RS256", JSON.parse(b64(header))["alg"]
    claims = JSON.parse(b64(payload))
    assert_equal account["client_email"], claims["iss"]
    assert_equal "https://www.googleapis.com/auth/firebase.messaging", claims["scope"]
    assert rsa.verify("SHA256", b64(signature), "#{header}.#{payload}")

    json = calls[1]
    assert_equal "https://fcm.googleapis.com/v1/projects/itsjustmy/messages:send", json[1]
    assert_equal "Bearer ya29.test", json[3]["authorization"]
    assert_equal "fcm-token", json[2].dig("message", "token")
    assert_equal "9", json[2].dig("message", "data", "post_id")
    assert_equal "Hola", json[2].dig("message", "notification", "title")
  end

  test "missing push secrets name the credentials to upload" do
    error = assert_raises(HotwireNativeShell::ConfigurationError) do
      HotwireNativeShell::Push::Credentials.new.require_apns!
    end

    assert_includes error.message, "HOTWIRE_NATIVE_SHELL_APNS_KEY_ID"
    assert_includes error.message, "private_key"
    assert_not_includes error.message, "BEGIN PRIVATE KEY"
  end

  class FakeHttp
    attr_accessor :apns_response, :form_response, :json_response
    attr_reader :apns_calls, :calls

    def initialize
      @apns_calls = []
      @calls = []
    end

    def apns(**kwargs)
      @apns_calls << kwargs
      apns_response
    end

    def post_form(url, form, headers: {})
      @calls << [ :form, url, form, headers ]
      form_response
    end

    def post_json(url, json, headers: {})
      @calls << [ :json, url, json, headers ]
      json_response
    end
  end

  def b64(segment)
    Base64.urlsafe_decode64(segment)
  end

  def raw_to_der(raw)
    r = OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(raw.byteslice(0, 32), 2))
    s = OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(raw.byteslice(32, 32), 2))
    OpenSSL::ASN1::Sequence.new([ r, s ]).to_der
  end
end
