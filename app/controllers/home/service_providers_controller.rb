module Home
  class ServiceProvidersController < ApplicationController
    before_action -> { require_role(:operator, :admin) }
    before_action :set_provider, only: [ :update ]

    def create
      ServiceProvider.create!(provider_params)
      redirect_to home_root_path(edit: 1), notice: "Provider created."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to home_root_path(edit: 1), alert: e.record.errors.full_messages.to_sentence
    end

    def update
      @provider.update!(provider_params)
      redirect_to home_root_path(edit: 1), notice: "Provider updated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to home_root_path(edit: 1), alert: e.record.errors.full_messages.to_sentence
    end

    private

    def set_provider
      @provider = ServiceProvider.find(params[:id])
    end

    def provider_params
      params.require(:service_provider).permit(:key, :name, :provider_type, :description)
    end
  end
end
