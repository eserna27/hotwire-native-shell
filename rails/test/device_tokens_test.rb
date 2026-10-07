# frozen_string_literal: true

require "test_helper"

class DeviceTokensTest < ActionDispatch::IntegrationTest
  test "placeholder tokens are ignored" do
    assert_no_difference -> { HotwireNativeShell::DeviceToken.count } do
      post native_device_tokens_path, params: {
        token: "placeholder-not-a-device-token",
        provider: "placeholder",
        platform: "ios"
      }, as: :json
    end

    assert_response :success
    assert_equal "ignored", response.parsed_body["status"]
  end

  test "a real token is stored for the signed-in owner and can be replaced" do
    user = User.create!(email: "writer@example.com")
    post test_session_path, params: { user_id: user.id }

    post native_device_tokens_path, params: { token: "fcm-1", provider: "fcm", platform: "android" }, as: :json

    assert_response :created
    record = HotwireNativeShell::DeviceToken.find_by!(token: "fcm-1")
    assert_equal user, record.owner
    assert_equal "fcm", record.provider
    assert_equal "android", record.platform
    assert_not_nil record.last_seen_at

    post native_device_tokens_path, params: { token: "fcm-1", provider: "fcm", platform: "android" }, as: :json

    assert_equal 1, HotwireNativeShell::DeviceToken.where(token: "fcm-1").count
  end

  test "a blank token is rejected" do
    post native_device_tokens_path, params: { token: "", provider: "apns" }, as: :json

    assert_response :unprocessable_entity
    assert_equal 0, HotwireNativeShell::DeviceToken.count
  end

  test "another owner cannot delete the token" do
    owner = User.create!(email: "owner@example.com")
    HotwireNativeShell::DeviceToken.register!(token: "abc", provider: "apns", platform: "ios", owner: owner)
    other = User.create!(email: "other@example.com")
    post test_session_path, params: { user_id: other.id }

    delete native_device_tokens_path, params: { token: "abc" }, as: :json

    assert_response :forbidden
    assert HotwireNativeShell::DeviceToken.exists?(token: "abc")
  end

  test "the owner can delete the token" do
    owner = User.create!(email: "owner@example.com")
    HotwireNativeShell::DeviceToken.register!(token: "abc", provider: "apns", platform: "ios", owner: owner)
    post test_session_path, params: { user_id: owner.id }

    delete native_device_tokens_path, params: { token: "abc" }, as: :json

    assert_response :no_content
    assert_not HotwireNativeShell::DeviceToken.exists?(token: "abc")
  end
end
