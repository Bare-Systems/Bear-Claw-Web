module Home
  class DevicesController < ApplicationController
    before_action -> { require_role(:operator, :admin) }
    before_action :set_device, only: [ :update ]

    def create
      Device.create!(device_params.merge(metadata: device_metadata, user: current_home.owner))
      redirect_to home_root_path(edit: 1), notice: "Device created."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to home_root_path(edit: 1), alert: e.record.errors.full_messages.to_sentence
    end

    def update
      @device.update!(device_params.merge(metadata: @device.metadata_hash.merge(device_metadata)))
      redirect_to home_root_path(edit: 1), notice: "Device updated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to home_root_path(edit: 1), alert: e.record.errors.full_messages.to_sentence
    end

    private

    def set_device
      @device = Device.for_home(current_home).find(params[:id])
    end

    def device_metadata
      {
        "location" => params.dig(:device, :location).presence,
        "notes" => params.dig(:device, :notes).presence
      }.compact
    end

    def device_params
      permitted = params.require(:device).permit(
        :service_connection_id,
        :parent_device_id,
        :key,
        :name,
        :category,
        :source_kind,
        :source_identifier,
        :status
      )
      permitted[:source_identifier] = nil if permitted[:source_identifier].blank?
      permitted[:parent_device_id] = nil if permitted[:parent_device_id].blank?
      permitted
    end
  end
end
