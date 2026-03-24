require "json"
require "net/http"
require "uri"

class KoalaClient
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

  Download = Struct.new(:body, :content_type, :headers, keyword_init: true)

  DEFAULT_CAMERA_IDS = (1..8).map { |number| "cam_#{number}" }.freeze

  def initialize(base_url:, token:)
    @base_url = base_url.to_s.strip
    @token = token.to_s.strip
  end

  def list_cameras
    request_json(Net::HTTP::Post, "/mcp/tools/koala.list_cameras", payload: { input: {} })
  end

  def snapshot(camera_id)
    response = perform(Net::HTTP::Get, "/admin/cameras/#{camera_id}/snapshot", accept: "image/jpeg")
    Download.new(
      body: response.body || +"",
      content_type: response["content-type"] || "application/octet-stream",
      headers: response.each_header.to_h
    )
  end

  private

  def request_json(http_class, path, params: {}, payload: nil)
    response = perform(http_class, path, params: params, payload: payload)
    content_type = response["content-type"].to_s

    unless content_type.include?("application/json")
      raise RequestError.new("Unexpected Koala response format", status: response.code.to_i, body: response.body.to_s)
    end

    JSON.parse(response.body.to_s)
  rescue JSON::ParserError => e
    raise RequestError.new("Invalid JSON from Koala: #{e.message}", status: 502, body: response&.body.to_s)
  end

  def perform(http_class, path, params: {}, payload: nil, accept: "application/json")
    validate_config!

    uri = build_uri(path, params)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 30

    request = http_class.new(uri)
    request["Authorization"] = "Bearer #{@token}"
    request["Accept"] = accept
    if payload
      request["Content-Type"] = "application/json"
      request.body = JSON.dump(payload)
    end

    response = http.request(request)
    unless response.code.to_i.between?(200, 299)
      message = begin
        parsed = JSON.parse(response.body.to_s)
        parsed["detail"] || parsed["message"] || parsed["explanation"] || response.message
      rescue JSON::ParserError
        response.body.to_s.presence || response.message
      end
      raise RequestError.new(message, status: response.code.to_i, body: response.body.to_s)
    end

    response
  rescue SocketError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => e
    raise RequestError.new("Koala request failed: #{e.message}", status: 502, body: "")
  end

  def validate_config!
    raise ConfigurationError, "KOALA_URL is not configured." if @base_url.blank?
    raise ConfigurationError, "KOALA_TOKEN is not configured." if @token.blank?
  end

  def build_uri(path, params)
    base = URI.parse(@base_url)
    uri = base.dup
    normalized_path = path.to_s.start_with?("/") ? path.to_s : "/#{path}"
    resolved_path = [ base.path.to_s.sub(%r{/\z}, ""), normalized_path.sub(%r{\A/}, "") ].reject(&:blank?).join("/")
    resolved_path = "/#{resolved_path}" unless resolved_path.start_with?("/")
    uri.path = resolved_path
    uri.query = params.compact_blank.to_query.presence
    uri
  end
end
