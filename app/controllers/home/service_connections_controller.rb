module Home
  class ServiceConnectionsController < ApplicationController
    before_action -> { require_role(:operator, :admin) }
    before_action :set_connection, only: [ :update ]

    def create
      ServiceConnection.create!(connection_params)
      redirect_to home_root_path(edit: 1), notice: "Connection created."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to home_root_path(edit: 1), alert: e.record.errors.full_messages.to_sentence
    end

    def update
      @connection.update!(connection_params)
      redirect_to home_root_path(edit: 1), notice: "Connection updated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to home_root_path(edit: 1), alert: e.record.errors.full_messages.to_sentence
    end

    private

    def set_connection
      @connection = ServiceConnection.find(params[:id])
    end

    def connection_params
      params.require(:service_connection).permit(
        :service_provider_id,
        :key,
        :name,
        :adapter,
        :base_url,
        :credential_strategy,
        :status
      )
    end
  end
end
