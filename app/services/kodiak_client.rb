require "json"
require "net/http"
require "uri"

class KodiakClient
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class RequestError < Error
    attr_reader :status, :body

    def initialize(message, status:, body:)
      super(message)
      @status = status
      @body = body
    end
  end

  def initialize(base_url:, token:, actor: nil, role: nil)
    @base_url = base_url.to_s.strip
    @token = token.to_s.strip
    @actor = actor.to_s.presence
    @role  = role.to_s.presence
  end

  # ── Engine ───────────────────────────────────────────────────────────────────

  def engine_status
    request_json("/api/v1/engine/status")
  end

  def start_engine(dry_run: true, interval: 60)
    request_json_post("/api/v1/engine/start", { dry_run: dry_run, interval: interval })
  end

  def stop_engine
    request_json_post("/api/v1/engine/stop", {})
  end

  # ── Portfolio ─────────────────────────────────────────────────────────────────

  def portfolio_summary
    request_json("/api/v1/portfolio/summary")
  end

  def positions
    request_json("/api/v1/portfolio/positions")
  end

  def movers(market_type: "stocks", limit: 10)
    request_json("/api/v1/portfolio/movers?market_type=#{market_type}&limit=#{limit}")
  end

  # ── Strategies ────────────────────────────────────────────────────────────────

  # Returns the array of strategy hashes (unwraps the StrategyListResponse envelope).
  def strategies
    result = request_json("/api/v1/strategies")
    result.is_a?(Hash) ? Array(result["strategies"]) : Array(result)
  end

  def strategy(id)
    request_json("/api/v1/strategies/#{id}")
  end

  def pause_strategy(id)
    request_json_post("/api/v1/strategies/#{id}/pause", {})
  end

  def resume_strategy(id)
    request_json_post("/api/v1/strategies/#{id}/resume", {})
  end

  # ── Orders ────────────────────────────────────────────────────────────────────

  def orders(show_all: false)
    request_json("/api/v1/orders?show_all=#{show_all}")
  end

  def cancel_order(id)
    request_delete("/api/v1/orders/#{id}")
  end

  private

  def request_json(path)
    validate_config!

    uri = build_uri(path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@token}"
    request["Accept"] = "application/json"
    apply_actor_headers!(request)

    perform(http, request)
  end

  def request_json_post(path, body)
    validate_config!

    uri = build_uri(path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@token}"
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    apply_actor_headers!(request)
    request.body = body.to_json

    perform(http, request)
  end

  def request_delete(path)
    validate_config!

    uri = build_uri(path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Delete.new(uri)
    request["Authorization"] = "Bearer #{@token}"
    request["Accept"] = "application/json"
    apply_actor_headers!(request)

    perform(http, request)
  end

  def apply_actor_headers!(request)
    request["X-BearClaw-Actor"] = @actor if @actor
    request["X-BearClaw-Role"]  = @role  if @role
  end

  def perform(http, request)
    response = http.request(request)
    body_str = response.body.to_s

    unless response.code.to_i.between?(200, 299)
      # Try to extract a human-readable message from the error envelope.
      message = begin
        parsed = JSON.parse(body_str)
        parsed.dig("error", "message") || parsed["detail"] || body_str.presence || response.message
      rescue JSON::ParserError
        body_str.presence || response.message
      end
      raise RequestError.new(message, status: response.code.to_i, body: body_str)
    end

    return nil if body_str.strip.empty?

    parsed = JSON.parse(body_str)

    # Unwrap the Kodiak v1 response envelope: {"data": ..., "error": null, "meta": {...}}
    parsed.is_a?(Hash) && parsed.key?("data") ? parsed["data"] : parsed
  rescue JSON::ParserError => e
    raise RequestError.new("Invalid JSON from Kodiak: #{e.message}", status: 502, body: body_str)
  rescue SocketError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => e
    raise RequestError.new("Kodiak request failed: #{e.message}", status: 502, body: "")
  end

  def validate_config!
    raise ConfigurationError, "KODIAK_URL is not configured." if @base_url.blank?
    raise ConfigurationError, "KODIAK_TOKEN is not configured." if @token.blank?
  end

  def build_uri(path)
    base = URI.parse(@base_url)
    uri = base.dup
    normalized_path = path.to_s.start_with?("/") ? path.to_s : "/#{path}"
    resolved_path = [ base.path.to_s.sub(%r{/\z}, ""), normalized_path.sub(%r{\A/}, "") ].reject(&:blank?).join("/")
    resolved_path = "/#{resolved_path}" unless resolved_path.start_with?("/")
    uri.path = resolved_path
    uri.query = nil
    # Preserve query string from path
    if (q = path.to_s.split("?", 2)[1])
      uri.query = q
    end
    uri
  end
end
