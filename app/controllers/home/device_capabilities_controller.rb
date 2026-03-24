module Home
  class DeviceCapabilitiesController < ApplicationController
    before_action -> { require_role(:operator, :admin) }
    before_action :set_capability, only: [ :update, :toggle ]

    def create
      DeviceCapability.create!(
        capability_params.merge(
          configuration: capability_configuration,
          state: capability_state
        )
      )
      redirect_to home_root_path(edit: 1), notice: "Capability created."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to home_root_path(edit: 1), alert: e.record.errors.full_messages.to_sentence
    end

    def update
      @capability.update!(
        capability_params.merge(
          configuration: @capability.configuration_hash.merge(capability_configuration),
          state: @capability.state_hash.merge(capability_state)
        )
      )
      redirect_to home_root_path(edit: 1), notice: "Capability updated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to home_root_path(edit: 1), alert: e.record.errors.full_messages.to_sentence
    end

    def toggle
      unless @capability.capability_type == "switch"
        redirect_to home_root_path, alert: "Only switch capabilities can be toggled." and return
      end

      new_value = !@capability.switch_on?
      @capability.update!(
        state: @capability.state_hash.merge(
          "value" => new_value,
          "status" => "available",
          "last_seen_at" => Time.current.iso8601
        )
      )

      redirect_back fallback_location: home_root_path, notice: "#{@capability.name} turned #{new_value ? "on" : "off"}."
    end

    private

    def set_capability
      @capability = DeviceCapability.joins(:device).where(devices: { user_id: current_home.owner_id }).find(params[:id])
    end

    def capability_configuration
      {
        "camera_id" => params.dig(:device_capability, :camera_id).presence,
        "selected_source" => params.dig(:device_capability, :selected_source).presence,
        "control_mode" => params.dig(:device_capability, :control_mode).presence
      }.compact
    end

    def capability_state
      state = {
        "status" => params.dig(:device_capability, :status_override).presence,
        "value" => normalized_value,
        "unit" => params.dig(:device_capability, :unit).presence,
        "last_seen_at" => params.dig(:device_capability, :last_seen_at).presence,
        "selected_source" => params.dig(:device_capability, :selected_source).presence
      }.compact

      state
    end

    def normalized_value
      raw = params.dig(:device_capability, :value)
      return if raw.nil?

      return ActiveModel::Type::Boolean.new.cast(raw) if boolean_capability?

      raw.presence
    end

    def boolean_capability?
      type = params.dig(:device_capability, :capability_type).presence || @capability&.capability_type
      type == "switch"
    end

    def capability_params
      params.require(:device_capability).permit(
        :device_id,
        :key,
        :name,
        :capability_type
      )
    end
  end
end
