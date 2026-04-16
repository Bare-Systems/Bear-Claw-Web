require "test_helper"

class SessionsControllerTest < ActionController::TestCase
  tests SessionsController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)
    @old_secret = ENV["TARDIGRADE_JWT_SECRET"]
    @old_issuer = ENV["TARDIGRADE_JWT_ISSUER"]
    @old_audience = ENV["TARDIGRADE_JWT_AUDIENCE"]
    ENV["TARDIGRADE_JWT_SECRET"] = "test-stage-2c-secret"
    ENV["TARDIGRADE_JWT_ISSUER"] = "bearclaw-web"
    ENV["TARDIGRADE_JWT_AUDIENCE"] = "bearclaw-api"
  end

  teardown do
    ENV["TARDIGRADE_JWT_SECRET"] = @old_secret
    ENV["TARDIGRADE_JWT_ISSUER"] = @old_issuer
    ENV["TARDIGRADE_JWT_AUDIENCE"] = @old_audience
  end

  test "google oauth callback stores a tardigrade identity token in session" do
    @request.env["omniauth.auth"] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: @user.google_uid,
      info: {
        email: @user.email,
        name: @user.name,
        image: @user.avatar_url
      }
    )

    get :create, params: { provider: "google_oauth2" }

    assert_redirected_to root_path
    assert_equal @user.id, @request.session[:user_id]

    token = @request.session[:tardigrade_identity_token]
    refute_nil token

    payload, = JWT.decode(
      token,
      "test-stage-2c-secret",
      true,
      algorithm: "HS256",
      iss: "bearclaw-web",
      verify_iss: true,
      aud: "bearclaw-api",
      verify_aud: true
    )

    assert_equal @user.id.to_s, payload["sub"]
    assert_equal "bearclaw.operator", payload["scope"]
    assert_equal "bearclaw-web", payload["device_id"]
  end
end
