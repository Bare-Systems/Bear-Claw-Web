module Security
  class NetworkController < BaseController
    def index
      payload  = ursa_client.get_json("/api/v1/network/devices")
      @counts  = payload["counts"] || {}
      @devices = payload["devices"] || []
      load_dns_talkers
    end

    def baseline
      result = ursa_client.post_json("/api/v1/network/baseline", payload: {})
      count  = result.is_a?(Hash) ? result["trusted"] : nil
      notice = count ? "Baseline set — #{count} device(s) marked trusted." : "Baseline set."
      redirect_to security_network_path, notice: notice
    end

    def update_device
      mac     = params[:mac].to_s
      payload = {}
      payload[:trusted] = ActiveModel::Type::Boolean.new.cast(params[:trusted]) unless params[:trusted].nil?
      payload[:label]   = params[:label] if params.key?(:label)

      ursa_client.patch_json("/api/v1/network/devices/#{mac}", payload: payload)
      redirect_to security_network_path, notice: "Device updated."
    end

    private

    # Pi-hole DNS insight is best-effort: an older Ursa without the /dns endpoint
    # (404) or an unreadable FTL DB must not blank out the device inventory table.
    def load_dns_talkers
      payload     = ursa_client.get_json("/api/v1/dns/talkers", params: { since_hours: 24, limit: 10 })
      @dns        = payload["overview"] || {}
      @dns_talkers = payload["talkers"] || []
    rescue UrsaClient::RequestError => e
      Rails.logger.info("[Security::Network] DNS insight unavailable: #{e.message}")
      @dns         = { "available" => false }
      @dns_talkers = []
    end
  end
end
