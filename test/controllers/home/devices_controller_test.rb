require "test_helper"

class Home::DevicesControllerTest < ActionController::TestCase
  tests Home::DevicesController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)
    @request.session[:user_id] = @user.id

    @household = Household.create!(name: "Test Home", owner: @user)
    HouseholdMembership.create!(household: @household, user: @user)

    provider = ServiceProvider.create!(key: "custom", name: "Custom", provider_type: "hybrid")
    @connection = ServiceConnection.create!(
      service_provider: provider,
      key: "custom-main",
      name: "Custom Main",
      adapter: "custom",
      credential_strategy: "environment",
      status: "online"
    )
  end

  test "creates a manual device" do
    assert_difference("Device.count", 1) do
      post :create, params: {
        device: {
          service_connection_id: @connection.id,
          key: "garage-light",
          name: "Garage Light",
          category: "switch",
          source_kind: "network",
          source_identifier: "garage-light",
          status: "available",
          location: "Garage",
          notes: "Zigbee relay"
        }
      }
    end

    device = Device.order(:id).last

    assert_redirected_to home_root_path(edit: 1)
    assert_equal "Garage", device.metadata_hash["location"]
    assert_equal "Zigbee relay", device.metadata_hash["notes"]
  end
end
