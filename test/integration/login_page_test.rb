require "test_helper"

class LoginPageTest < ActionDispatch::IntegrationTest
  test "login page renders with the shared layout assets and disables turbo prefetch" do
    get login_path

    assert_response :success
    assert_select "h1", text: "BearClaw"
    assert_select "meta[name='turbo-prefetch'][content='false']"
    assert_select "link[href*='tailwind']"
  end
end
