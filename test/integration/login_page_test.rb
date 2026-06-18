require "test_helper"

class LoginPageTest < ActionDispatch::IntegrationTest
  setup do
    @old_oidc_support_enabled = ENV["OIDC_SUPPORT_ENABLED"]
    @old_oidc_issuer_url = ENV["OIDC_ISSUER_URL"]
    @old_oidc_client_id = ENV["OIDC_CLIENT_ID"]
    @old_oidc_client_secret = ENV["OIDC_CLIENT_SECRET"]
    @old_oidc_redirect_uri = ENV["OIDC_REDIRECT_URI"]
    # Default support login OFF so these tests don't depend on the ambient
    # environment — the homelab/container env sets OIDC_SUPPORT_ENABLED=true,
    # which previously leaked in and rendered the support button unexpectedly.
    # The "enabled by config" test opts back in explicitly.
    ENV["OIDC_SUPPORT_ENABLED"] = "false"
  end

  teardown do
    ENV["OIDC_SUPPORT_ENABLED"] = @old_oidc_support_enabled
    ENV["OIDC_ISSUER_URL"] = @old_oidc_issuer_url
    ENV["OIDC_CLIENT_ID"] = @old_oidc_client_id
    ENV["OIDC_CLIENT_SECRET"] = @old_oidc_client_secret
    ENV["OIDC_REDIRECT_URI"] = @old_oidc_redirect_uri
  end

  test "login page renders with the shared layout assets and disables turbo prefetch" do
    get login_path

    assert_response :success
    assert_select "h1", text: "BearClaw"
    assert_select "button", text: "Continue with Google"
    assert_select "button", text: "Continue with Support Login", count: 0
    assert_select "meta[name='turbo-prefetch'][content='false']"
    assert_select "meta[name='action-cable-url'][content$='/cable']"
    assert_select "link[href*='tailwind']"
    assert_select "script[nonce]", minimum: 1

    csp = response.headers["Content-Security-Policy"]
    assert_includes csp, "script-src"
    assert_includes csp, "style-src"
    assert_includes csp, "connect-src"
    assert_includes csp, "img-src"
    assert_includes csp, "'unsafe-inline'"
  end

  test "login page renders the support oidc button when enabled by config" do
    ENV["OIDC_SUPPORT_ENABLED"] = "true"
    ENV["OIDC_ISSUER_URL"] = "http://192.168.86.53:8180/realms/ekho"
    ENV["OIDC_CLIENT_ID"] = "bearclaw-web"
    ENV["OIDC_CLIENT_SECRET"] = "test-secret"
    ENV["OIDC_REDIRECT_URI"] = "https://bearclaw.baresystems.com/auth/oidc/callback"

    get login_path

    assert_response :success
    assert_select "button", text: "Continue with Support Login"
    assert_select "p", text: /Support Login is only for configured test accounts/
  end
end
