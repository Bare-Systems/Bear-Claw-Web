module KoalaCameraSlots
  extend ActiveSupport::Concern

  private

  def build_camera_slots
    payload = koala_client.list_cameras
    cameras = payload.dig("data", "cameras") || []
    cameras_by_id = cameras.index_by { |camera| camera["id"] }

    KoalaClient::DEFAULT_CAMERA_IDS.map do |camera_id|
      camera = cameras_by_id[camera_id] || {}
      capability = camera["capability"] || {}
      status = camera["status"].presence || "unknown"

      {
        id: camera_id,
        name: camera["name"].presence || camera_id.upcase.tr("_", " "),
        status: status,
        zone_id: camera["zone_id"].presence || "unassigned",
        selected_source: capability["selected_source"].presence || "snapshot",
        last_error: capability["last_error"].presence,
        last_probed_at: capability["last_probed_at"].presence,
        snapshot_path: snapshot_home_camera_path(camera_id)
      }
    end
  end

  def koala_client
    @koala_client ||= KoalaClient.new(
      base_url: ENV["KOALA_URL"],
      token: ENV["KOALA_TOKEN"]
    )
  end
end
