require "test_helper"

class SessionsControllerTest < ActionController::TestCase
  tests SessionsController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)
    @support_user = User.create!(
      email: "support-test@bearclaw.local",
      name: "Support Test",
      avatar_url: nil,
      google_uid: "pending-support-oidc",
      role: :operator
    )
    @old_secret = ENV["TARDIGRADE_JWT_SECRET"]
    @old_issuer = ENV["TARDIGRADE_JWT_ISSUER"]
    @old_audience = ENV["TARDIGRADE_JWT_AUDIENCE"]
    @old_oidc_allowed_emails = ENV["OIDC_ALLOWED_EMAILS"]
    ENV["TARDIGRADE_JWT_SECRET"] = "test-stage-2c-secret"
    ENV["TARDIGRADE_JWT_ISSUER"] = "bearclaw-web"
    ENV["TARDIGRADE_JWT_AUDIENCE"] = "bearclaw-api"
  end

  teardown do
    ENV["TARDIGRADE_JWT_SECRET"] = @old_secret
    ENV["TARDIGRADE_JWT_ISSUER"] = @old_issuer
    ENV["TARDIGRADE_JWT_AUDIENCE"] = @old_audience
    ENV["OIDC_ALLOWED_EMAILS"] = @old_oidc_allowed_emails
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

  test "support oidc callback signs in an allowlisted test account" do
    ENV["OIDC_ALLOWED_EMAILS"] = @support_user.email

    @request.env["omniauth.auth"] = OmniAuth::AuthHash.new(
      provider: "oidc",
      uid: "keycloak-support-subject",
      info: {
        email: @support_user.email,
        name: @support_user.name,
        image: nil
      }
    )

    get :create, params: { provider: "oidc" }

    assert_redirected_to root_path
    assert_equal @support_user.id, @request.session[:user_id]
    assert_equal "oidc:keycloak-support-subject", @support_user.reload.google_uid
  end

  test "support oidc callback rejects non-allowlisted accounts" do
    ENV["OIDC_ALLOWED_EMAILS"] = "other-user@bearclaw.local"

    @request.env["omniauth.auth"] = OmniAuth::AuthHash.new(
      provider: "oidc",
      uid: "blocked-support-subject",
      info: {
        email: @support_user.email,
        name: @support_user.name,
        image: nil
      }
    )

    get :create, params: { provider: "oidc" }

    assert_redirected_to login_path
    assert_equal "This support login is not enabled for your account.", flash[:alert]
  end
end
