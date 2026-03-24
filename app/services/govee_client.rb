require "json"
require "net/http"
require "uri"

# HTTP client for the Govee Open API.
#
# API key is passed as the `Govee-API-Key` header.
# Base URL: https://openapi.api.govee.com
#
# Relevant endpoints:
#   GET  /router/api/v1/user/devices     — list all devices
#   POST /router/api/v1/device/state     — fetch device state
class GoveeClient
  BASE_URL = "https://openapi.api.govee.com".freeze

  class Error             < StandardError; end
  class ConfigurationError < Error; end

  class RequestError < Error
    attr_reader :status, :body

    def initialize(message, status:, body:)
      super(message)
      @status = status
      @body   = body
    end
  end

  def initialize(api_key:)
    @api_key = api_key.to_s.strip
  end

  # Returns the raw array of device hashes from Govee.
  # Shape: [{ sku:, device:, deviceName:, type:, supportCmds: [] }, …]
  def devices
    response = request_json("GET", "/router/api/v1/user/devices")
    Array(response["data"])
  end

  # Returns the state for a single device.
  # Shape: { sku:, device:, capabilities: [{ type:, instance:, state: { value: } }] }
  def device_state(sku:, device_id:)
    payload = { requestId: SecureRandom.uuid, payload: { sku: sku, device: device_id } }
    response = request_json("POST", "/router/api/v1/device/state", body: payload)
    response.dig("payload") || {}
  end

  private

  def request_json(method, path, body: nil)
    validate_config!

    uri  = URI.parse("#{BASE_URL}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.open_timeout = 10
    http.read_timeout = 30

    request = case method.upcase
              when "GET"  then Net::HTTP::Get.new(uri)
              when "POST" then Net::HTTP::Post.new(uri)
              else raise ArgumentError, "Unsupported method: #{method}"
              end

    request["Govee-API-Key"] = @api_key
    request["Content-Type"]  = "application/json"
    request["Accept"]        = "application/json"

    if body
      request.body = JSON.generate(body)
    end

    response = http.request(request)

    unless response.code.to_i.between?(200, 299)
      raise RequestError.new(
        response.body.to_s.presence || response.message,
        status: response.code.to_i,
        body:   response.body.to_s
      )
    end

    parsed = JSON.parse(response.body.to_s)

    # Govee wraps errors in a 200 response with a non-200 code field.
    govee_code = parsed["code"].to_i
    unless govee_code.zero? || govee_code == 200
      raise RequestError.new(
        parsed["message"].presence || "Govee API error (code #{govee_code})",
        status: govee_code,
        body:   response.body.to_s
      )
    end

    parsed
  rescue JSON::ParserError => e
    raise RequestError.new("Invalid JSON from Govee: #{e.message}", status: 502, body: response&.body.to_s)
  rescue SocketError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => e
    raise RequestError.new("Govee request failed: #{e.message}", status: 502, body: "")
  end

  def validate_config!
    raise ConfigurationError, "Govee API key is not configured." if @api_key.blank?
  end
end
