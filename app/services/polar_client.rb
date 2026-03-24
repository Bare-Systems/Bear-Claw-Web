require "json"
require "net/http"
require "uri"

class PolarClient
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

  # Returns an array of the most recent reading per sensor/metric pair.
  # Shape: [{ station_id:, sensor_id:, metric:, value:, unit:, source:,
  #           quality_flag:, recorded_at:, received_at: }, ...]
  def latest_readings
    request_json("/v1/readings/latest")
  end

  # Returns station-level health summary.
  # Shape: { station_id:, overall:, components: [...], generated_at: }
  def station_health
    request_json("/v1/station/health")
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

    response = http.request(request)
    unless response.code.to_i.between?(200, 299)
      raise RequestError.new(response.body.to_s.presence || response.message, status: response.code.to_i, body: response.body.to_s)
    end

    JSON.parse(response.body.to_s)
  rescue JSON::ParserError => e
    raise RequestError.new("Invalid JSON from Polar: #{e.message}", status: 502, body: response&.body.to_s)
  rescue SocketError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => e
    raise RequestError.new("Polar request failed: #{e.message}", status: 502, body: "")
  end

  def validate_config!
    raise ConfigurationError, "POLAR_URL is not configured." if @base_url.blank?
    raise ConfigurationError, "POLAR_TOKEN is not configured." if @token.blank?
  end

  def build_uri(path)
    base = URI.parse(@base_url)
    uri = base.dup
    normalized_path = path.to_s.start_with?("/") ? path.to_s : "/#{path}"
    resolved_path = [ base.path.to_s.sub(%r{/\z}, ""), normalized_path.sub(%r{\A/}, "") ].reject(&:blank?).join("/")
    resolved_path = "/#{resolved_path}" unless resolved_path.start_with?("/")
    uri.path = resolved_path
    uri.query = nil
    uri
  end
end
