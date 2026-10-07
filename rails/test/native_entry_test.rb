# frozen_string_literal: true

require "test_helper"

class NativeEntryTest < ActionDispatch::IntegrationTest
  test "signed-out native html visits go to sign-in" do
    get root_path, headers: { "User-Agent" => native_user_agent }

    assert_redirected_to "/users/sign_in"
  end

  test "an allowed signed-out path stays put" do
    get entry_path, headers: { "User-Agent" => native_user_agent }

    assert_response :success
    assert_equal "entry", response.body
  end

  test "a browser is not redirected" do
    get root_path, headers: { "User-Agent" => "Mozilla/5.0" }

    assert_response :success
  end

  test "turbo native alone is not redirected" do
    get root_path, headers: { "User-Agent" => "Turbo Native Android" }

    assert_response :success
  end

  test "signed-in native root opens the signed-in start path" do
    user = User.create!(email: "writer@example.com")
    post test_session_path, params: { user_id: user.id }

    get root_path, headers: { "User-Agent" => native_user_agent }

    assert_redirected_to "/dashboard"
  end

  test "json requests are not redirected" do
    get entry_path, headers: { "User-Agent" => native_user_agent, "Accept" => "application/json" }

    assert_response :success
  end
end
