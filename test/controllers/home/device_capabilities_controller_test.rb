require "test_helper"

class Home::DeviceCapabilitiesControllerTest < ActionController::TestCase
  tests Home::DeviceCapabilitiesController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)
    @request.session[:user_id] = @user.id

    @household = Household.create!(name: "Test Home", owner: @user)
    HouseholdMembership.create!(household: @household, user: @user)

    provider = ServiceProvider.create!(key: "custom", name: "Custom", provider_type: "hybrid")
    connection = ServiceConnection.create!(
      service_provider: provider,
      key: "custom-main",
      name: "Custom Main",
      adapter: "custom",
      credential_strategy: "environment",
      status: "online"
    )
    @device = Device.create!(
      service_connection: connection,
      user: @user,
      key: "garage-light",
      name: "Garage Light",
      category: "switch",
      source_kind: "network",
      source_identifier: "garage-light",
      status: "available"
    )
  end

  test "creates a switch capability" do
    assert_difference("DeviceCapability.count", 1) do
      post :create, params: {
        device_capability: {
          device_id: @device.id,
          key: "main_switch",
          name: "Main Switch",
          capability_type: "switch",
          value: "true",
          status_override: "available",
          selected_source: "manual",
          control_mode: "manual"
        }
      }
    end

    capability = DeviceCapability.order(:id).last

    assert_redirected_to home_root_path(edit: 1)
    assert_equal true, capability.current_value
    assert_equal "manual", capability.configuration_hash["control_mode"]
  end

  test "toggles a manual switch capability" do
    capability = DeviceCapability.create!(
      device: @device,
      key: "main_switch",
      name: "Main Switch",
      capability_type: "switch",
      configuration: { "control_mode" => "manual" },
      state: { "value" => false, "status" => "available" }
    )

    post :toggle, params: { id: capability.id }

    assert_redirected_to home_root_path
    assert_equal true, capability.reload.switch_on?
    assert_equal "available", capability.state_hash["status"]
  end
end
