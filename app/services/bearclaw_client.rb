require "json"
require "net/http"
require "uri"

class BearClawClient
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class TimeoutError < Error; end

  class RequestError < Error
    attr_reader :status, :body

    def initialize(message, status:, body:)
      super(message)
      @status = status
      @body   = body
    end
  end

  def initialize(base_url:, token: nil)
    @base_url = base_url.to_s.strip
    @token    = token.to_s.strip.presence
  end

  def health
    get_json("/health")
  end

  # ── Chat ──────────────────────────────────────────────────────────────────

  def chat(message)
    post_json("/v1/chat", payload: { message: message })
  end

  # ── Cron ──────────────────────────────────────────────────────────────────

  def list_cron_jobs
    get_json("/v1/cron")
  end

  def create_cron_job(name:, schedule:, command:, args: {}, enabled: true)
    post_json("/v1/cron", payload: { name: name, schedule: schedule, command: command, args: args, enabled: enabled })
  end

  def update_cron_job(id, **attrs)
    patch_json("/v1/cron/#{id}", payload: attrs.compact)
  end

  def delete_cron_job(id)
    delete_json("/v1/cron/#{id}")
  end

  # ── Memory ────────────────────────────────────────────────────────────────

  def list_memory
    get_json("/v1/memory")
  end

  def delete_memory_entry(id)
    delete_json("/v1/memory/#{id}")
  end

  private

  def get_json(path)
    response = perform(Net::HTTP::Get, path)
    JSON.parse(response.body.to_s)
  rescue JSON::ParserError => e
    raise RequestError.new("Invalid JSON from BearClaw: #{e.message}", status: 502, body: response&.body.to_s)
  end

  def post_json(path, payload: {})
    response = perform(Net::HTTP::Post, path, payload: payload)
    JSON.parse(response.body.to_s)
  rescue JSON::ParserError => e
    raise RequestError.new("Invalid JSON from BearClaw: #{e.message}", status: 502, body: response&.body.to_s)
  end

  def patch_json(path, payload: {})
    response = perform(Net::HTTP::Patch, path, payload: payload)
    JSON.parse(response.body.to_s)
  rescue JSON::ParserError => e
    raise RequestError.new("Invalid JSON from BearClaw: #{e.message}", status: 502, body: response&.body.to_s)
  end

  def delete_json(path)
    response = perform(Net::HTTP::Delete, path)
    JSON.parse(response.body.to_s)
  rescue JSON::ParserError => e
    raise RequestError.new("Invalid JSON from BearClaw: #{e.message}", status: 502, body: response&.body.to_s)
  end

  def perform(http_class, path, payload: nil)
    validate_config!

    uri  = build_uri(path)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 150 # BearClaw agent has a 120s execution timeout (CPU-inference headroom)

    request = http_class.new(uri)
    request["Accept"]          = "application/json"
    request["X-BearClaw-Actor"] = "bearclaw-web"
    request["Authorization"]   = "Bearer #{@token}" if @token

    if payload
      request["Content-Type"] = "application/json"
      request.body = JSON.dump(payload)
    end

    response = http.request(request)

    unless response.code.to_i.between?(200, 299)
      message = begin
        parsed = JSON.parse(response.body.to_s)
        parsed["message"] || parsed["detail"] || response.message
      rescue JSON::ParserError
        response.body.to_s.presence || response.message
      end
      raise RequestError.new(message, status: response.code.to_i, body: response.body.to_s)
    end

    response
  rescue Timeout::Error
    raise TimeoutError, "BearClaw did not respond in time"
  rescue SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError => e
    raise RequestError.new("BearClaw request failed: #{e.message}", status: 502, body: "")
  end

  def validate_config!
    raise ConfigurationError, "BEARCLAW_URL is not configured" if @base_url.blank?
  end

  def build_uri(path)
    base     = URI.parse(@base_url)
    uri      = base.dup
    uri.path = path.to_s.start_with?("/") ? path.to_s : "/#{path}"
    uri
  end
end
