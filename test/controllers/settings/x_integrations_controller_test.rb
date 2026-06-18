require "test_helper"

class Settings::XIntegrationsControllerTest < ActionController::TestCase
  tests Settings::XIntegrationsController

  setup do
    Integration.delete_all
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)
    @request.session[:user_id] = @user.id
    # These tests assert the OAuth redirect_uri falls back to settings_x_callback_url,
    # which requires X_REDIRECT_URI unset. The homelab/container env sets it to the
    # production callback, so clear it for the test and restore in teardown.
    @old_x_redirect_uri = ENV.delete("X_REDIRECT_URI")
  end

  teardown do
    ENV["X_REDIRECT_URI"] = @old_x_redirect_uri if @old_x_redirect_uri
  end

  test "connect redirects to x authorization url and stores pkce session data" do
    received = {}
    fake = Object.new
    fake.define_singleton_method(:configured?) { true }
    fake.define_singleton_method(:generate_verifier) { "verifier-123" }
    fake.define_singleton_method(:build_authorization) do |verifier:, state:, redirect_uri:|
      received[:verifier] = verifier
      received[:redirect_uri] = redirect_uri
      "https://x.com/i/oauth2/authorize?state=#{state}"
    end

    original_x_client = @controller.method(:x_oauth_client)
    @controller.define_singleton_method(:x_oauth_client) { fake }
    begin
      get :connect
    ensure
      @controller.define_singleton_method(:x_oauth_client) { original_x_client.call }
    end

    assert_response :redirect
    assert_match "https://x.com/i/oauth2/authorize", @response.redirect_url
    assert_equal "verifier-123", received[:verifier]
    assert_equal settings_x_callback_url, received[:redirect_uri]
    assert_equal "verifier-123", @request.session[:x_oauth_verifier]
    assert @request.session[:x_oauth_state].present?
  end

  test "callback saves x integration and hands tokens to kodiak" do
    x_exchange = {}
    kodiak_payload = {}
    x_client = Object.new
    x_client.define_singleton_method(:exchange_code!) do |code:, verifier:, redirect_uri:|
      x_exchange[:code] = code
      x_exchange[:verifier] = verifier
      x_exchange[:redirect_uri] = redirect_uri
      {
        "access_token" => "access-1",
        "refresh_token" => "refresh-1",
        "token_type" => "bearer",
        "scope" => "tweet.read users.read offline.access",
        "expires_in" => 7200
      }
    end
    x_client.define_singleton_method(:me!) do |access_token:|
      x_exchange[:me_access_token] = access_token
      { "data" => { "id" => "42", "username" => "signaldesk", "name" => "Signal Desk" } }
    end

    kodiak = Object.new
    kodiak.define_singleton_method(:connect_x_oauth) do |**payload|
      kodiak_payload.merge!(payload)
    end

    @request.session[:x_oauth_verifier] = "verifier-123"
    @request.session[:x_oauth_state] = "state-123"

    original_x_client = @controller.method(:x_oauth_client)
    original_kodiak_client = @controller.method(:kodiak_client)
    @controller.define_singleton_method(:x_oauth_client) { x_client }
    @controller.define_singleton_method(:kodiak_client) { kodiak }
    begin
        get :callback, params: { code: "code-123", state: "state-123" }
    ensure
      @controller.define_singleton_method(:x_oauth_client) { original_x_client.call }
      @controller.define_singleton_method(:kodiak_client) { original_kodiak_client.call }
    end

    assert_redirected_to settings_integrations_path
    assert_equal "code-123", x_exchange[:code]
    assert_equal "verifier-123", x_exchange[:verifier]
    assert_equal settings_x_callback_url, x_exchange[:redirect_uri]
    assert_equal "access-1", x_exchange[:me_access_token]
    assert_equal "42", kodiak_payload[:x_user_id]
    assert_equal "signaldesk", kodiak_payload[:username]
    assert_equal "access-1", kodiak_payload[:access_token]
    assert_equal "refresh-1", kodiak_payload[:refresh_token]
    integration = Integration.find_by!(provider_key: "x")
    assert_equal "connected", integration.status
    assert_equal "signaldesk", integration.credentials["username"]
    assert_equal "42", integration.credentials["x_user_id"]
  end
end
