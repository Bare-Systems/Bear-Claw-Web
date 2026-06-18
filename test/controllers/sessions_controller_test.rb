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
    @old_portal_sso_enabled = ENV["PORTAL_SSO_ENABLED"]
    ENV["TARDIGRADE_JWT_SECRET"] = "test-stage-2c-secret"
    ENV["TARDIGRADE_JWT_ISSUER"] = "bearclaw-web"
    ENV["TARDIGRADE_JWT_AUDIENCE"] = "bearclaw-api"
    ENV["PORTAL_SSO_ENABLED"] = "true"
  end

  teardown do
    ENV["TARDIGRADE_JWT_SECRET"] = @old_secret
    ENV["TARDIGRADE_JWT_ISSUER"] = @old_issuer
    ENV["TARDIGRADE_JWT_AUDIENCE"] = @old_audience
    ENV["OIDC_ALLOWED_EMAILS"] = @old_oidc_allowed_emails
    ENV["PORTAL_SSO_ENABLED"] = @old_portal_sso_enabled
  end

  def portal_token(email:, name: "Joe", role: "owner", **overrides)
    now = Time.now.to_i
    payload = {
      "sub" => email,
      "email" => email,
      "name" => name,
      "role" => role,
      "tenant_id" => "home-joe",
      "site_id" => "beelink",
      "iss" => "portal",
      "aud" => "bearclaw-web",
      "iat" => now,
      "exp" => now + 60
    }.merge(overrides.transform_keys(&:to_s))
    JWT.encode(payload, PortalIdentityToken.secret, "HS256")
  end

  test "portal sso owner token signs in with operator role and edit access" do
    @user.update!(role: :viewer)
    get :portal, params: { token: portal_token(email: @user.email, role: "owner") }

    assert_redirected_to root_path
    assert_equal @user.id, @request.session[:user_id]
    assert_equal "operator", @user.reload.role
    refute_nil @request.session[:tardigrade_identity_token]
  end

  test "portal sso viewer token signs in with read-only role" do
    @user.update!(role: :operator)
    get :portal, params: { token: portal_token(email: @user.email, role: "viewer") }

    assert_redirected_to root_path
    assert_equal "viewer", @user.reload.role
  end

  test "portal sso never demotes an existing admin owner" do
    @user.update!(role: :admin)
    get :portal, params: { token: portal_token(email: @user.email, role: "owner") }

    assert_equal "admin", @user.reload.role
  end

  test "portal sso preserves the existing google identity" do
    original_uid = @user.google_uid
    get :portal, params: { token: portal_token(email: @user.email, role: "owner") }

    assert_equal original_uid, @user.reload.google_uid
  end

  test "portal sso rejects a token signed with the wrong secret" do
    bad = JWT.encode(
      { "email" => @user.email, "role" => "owner", "iss" => "portal", "aud" => "bearclaw-web",
        "exp" => Time.now.to_i + 60 },
      "not-the-portal-secret",
      "HS256"
    )
    get :portal, params: { token: bad }

    assert_redirected_to login_path
    assert_nil @request.session[:user_id]
  end

  test "portal sso rejects an expired token" do
    get :portal, params: { token: portal_token(email: @user.email, exp: Time.now.to_i - 5) }

    assert_redirected_to login_path
    assert_nil @request.session[:user_id]
  end

  test "portal sso refuses unknown users without an invite" do
    get :portal, params: { token: portal_token(email: "stranger@example.com") }

    assert_redirected_to login_path
    assert_equal "Access to BearClaw is by invitation only.", flash[:alert]
    assert_nil @request.session[:user_id]
  end

  test "portal sso route is hidden when disabled" do
    ENV["PORTAL_SSO_ENABLED"] = "false"
    assert_raises(ActionController::RoutingError) do
      get :portal, params: { token: portal_token(email: @user.email) }
    end
  end

  test "logout returns to the portal device dashboard when PORTAL_URL is set" do
    old = ENV["PORTAL_URL"]
    ENV["PORTAL_URL"] = "https://portal.baresystems.com"
    @request.session[:user_id] = @user.id
    post :destroy
    assert_redirected_to "https://portal.baresystems.com/app"
    assert_nil @request.session[:user_id]
  ensure
    ENV["PORTAL_URL"] = old
  end

  test "logout falls back to local login without PORTAL_URL" do
    old = ENV["PORTAL_URL"]
    ENV.delete("PORTAL_URL")
    @request.session[:user_id] = @user.id
    post :destroy
    assert_redirected_to login_path
  ensure
    ENV["PORTAL_URL"] = old
  end

  test "login page redirects to the portal device dashboard when PORTAL_URL is set" do
    old = ENV["PORTAL_URL"]
    ENV["PORTAL_URL"] = "https://portal.baresystems.com"
    get :new
    assert_redirected_to "https://portal.baresystems.com/app"
  ensure
    ENV["PORTAL_URL"] = old
  end

  test "login page renders locally without PORTAL_URL" do
    old = ENV["PORTAL_URL"]
    ENV.delete("PORTAL_URL")
    get :new
    assert_response :success
  ensure
    ENV["PORTAL_URL"] = old
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
