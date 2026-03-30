module Finances
  class OrdersController < BaseController
    def index
      @orders = kodiak_client.orders(show_all: params[:show_all] == "1")
    rescue KodiakClient::RequestError => e
      @error = "Could not reach Kodiak (#{e.status}): #{e.message}"
    rescue KodiakClient::Error => e
      @error = e.message
    end

    def destroy
      kodiak_client.cancel_order(params[:id])
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.remove("order_#{params[:id]}") }
        format.html { redirect_to finances_orders_path, notice: "Order cancelled." }
      end
    rescue KodiakClient::Error => e
      flash[:alert] = "Failed to cancel order: #{e.message}"
      redirect_to finances_orders_path
    end
  end
end
