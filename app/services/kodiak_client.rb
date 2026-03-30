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

  def initialize(base_url:, token:)
    @base_url = base_url.to_s.strip
    @token = token.to_s.strip
  end

  # ── Engine ───────────────────────────────────────────────────────────────────

  def engine_status
    request_json("/api/engine/status")
  end

  def start_engine(dry_run: true, interval: 60)
    request_json_post("/api/engine/start", { dry_run: dry_run, interval: interval })
  end

  def stop_engine
    request_json_post("/api/engine/stop", {})
  end

  # ── Portfolio ─────────────────────────────────────────────────────────────────

  def portfolio_summary
    request_json("/api/portfolio/summary")
  end

  def positions
    request_json("/api/portfolio/positions")
  end

  def movers(market_type: "stocks", limit: 10)
    request_json("/api/portfolio/movers?market_type=#{market_type}&limit=#{limit}")
  end

  # ── Strategies ────────────────────────────────────────────────────────────────

  def strategies
    request_json("/api/strategies")
  end

  def strategy(id)
    request_json("/api/strategies/#{id}")
  end

  def pause_strategy(id)
    request_json_post("/api/strategies/#{id}/pause", {})
  end

  def resume_strategy(id)
    request_json_post("/api/strategies/#{id}/resume", {})
  end

  # ── Orders ────────────────────────────────────────────────────────────────────

  def orders(show_all: false)
    request_json("/api/orders?show_all=#{show_all}")
  end

  def cancel_order(id)
    request_delete("/api/orders/#{id}")
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

    perform(http, request)
  end

  def perform(http, request)
    response = http.request(request)
    unless response.code.to_i.between?(200, 299)
      raise RequestError.new(response.body.to_s.presence || response.message, status: response.code.to_i, body: response.body.to_s)
    end

    return nil if response.body.to_s.strip.empty?
    JSON.parse(response.body.to_s)
  rescue JSON::ParserError => e
    raise RequestError.new("Invalid JSON from Kodiak: #{e.message}", status: 502, body: response&.body.to_s)
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
