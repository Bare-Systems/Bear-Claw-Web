require "test_helper"

class Home::ServiceProvidersControllerTest < ActionController::TestCase
  tests Home::ServiceProvidersController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)
    @request.session[:user_id] = @user.id
  end

  test "creates a provider" do
    assert_difference("ServiceProvider.count", 1) do
      post :create, params: {
        service_provider: {
          key: "polar",
          name: "Polar",
          provider_type: "network",
          description: "Climate and air quality APIs"
        }
      }
    end

    provider = ServiceProvider.order(:id).last

    assert_redirected_to home_root_path(edit: 1)
    assert_equal "polar", provider.key
    assert_equal "network", provider.provider_type
  end
end
