# Dev-only: seed a local household + camera tiles so the home dashboard renders
# real camera feeds against the mock Koala. Run with:
#   KOALA_URL=http://127.0.0.1:8082 KOALA_TOKEN=dev bin/rails runner dev/seed_local_cameras.rb
abort("development only") unless Rails.env.development?

user = User.find_or_create_by!(email: "dev@bearclaw.local") do |u|
  u.name = "Dev Admin"
  u.google_uid = "dev-local-admin"
  u.role = :admin
end

household = Household.find_or_create_by!(owner: user) { |h| h.name = "Dev Home" }
HouseholdMembership.find_or_create_by!(household: household, user: user) { |m| m.role = "owner" }

# Pull cameras from mock Koala into devices/capabilities.
if ENV["KOALA_URL"].present?
  client = KoalaClient.new(base_url: ENV["KOALA_URL"], token: ENV["KOALA_TOKEN"])
  Home::KoalaDeviceSync.new(client: client, base_url: ENV["KOALA_URL"], user: user).sync!
  puts "Koala sync done."
end

cam_caps = DeviceCapability.joins(:device)
                           .where(devices: { user_id: user.id })
                           .select { |c| c.default_widget_type == "camera_feed" }
puts "camera capabilities: #{cam_caps.size}"

dashboard = Dashboard.fetch_or_create_for!(user: user, context: :home, name: "Home Dashboard")
dashboard = Home::DashboardDensityUpgrader.new(dashboard: dashboard).upgrade!

# Add up to 3 camera tiles if not already present.
existing_cap_ids = dashboard.dashboard_tiles
                            .flat_map(&:dashboard_widgets)
                            .map(&:device_capability_id).compact.to_set

cam_caps.first(3).each_with_index do |cap, i|
  next if existing_cap_ids.include?(cap.id)
  position = dashboard.dashboard_tiles.maximum(:position).to_i + 1
  width = dashboard.default_tile_span(base_span: 3)
  height = dashboard.default_camera_tile_height(base_width: 3)
  slots = [ dashboard.columns / width, 1 ].max
  row = ((position - 1) / slots) * width + 1
  column = (((position - 1) % slots) * width) + 1
  DashboardTile.transaction do
    tile = dashboard.dashboard_tiles.create!(
      title: cap.device&.name.presence || cap.name,
      row: row, column: column, width: width, height: height, position: position, settings: {}
    )
    tile.dashboard_widgets.create!(
      device_capability: cap, widget_type: cap.default_widget_type,
      title: cap.name, position: 1, settings: { "refresh_interval_seconds" => 2 }
    )
    Home::DashboardLayoutNormalizer.new(dashboard: dashboard).normalize!(anchor_tile: tile)
  end
  puts "added camera tile for #{cap.name} (w=#{width} h=#{height})"
end

puts "dashboard tiles now: #{dashboard.dashboard_tiles.count}"
dashboard.dashboard_tiles.each do |t|
  kinds = t.dashboard_widgets.map(&:widget_type).join(",")
  puts "  tile ##{t.id} #{t.title} row=#{t.row} col=#{t.column} w=#{t.width} h=#{t.height} [#{kinds}]"
end
