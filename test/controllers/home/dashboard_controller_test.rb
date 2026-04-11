require "test_helper"
require "securerandom"

class Home::DashboardControllerTest < ActionController::TestCase
  tests Home::DashboardController

  setup do
    HouseholdMembership.delete_all
    Household.delete_all

    token = SecureRandom.hex(6)
    @provider_key = "koala-#{token}"
    @connection_key = "koala-main-#{token}"
    @user = User.create!(
      email: "dashboard-controller-#{token}@example.com",
      google_uid: "dashboard-controller-#{token}",
      name: "Dashboard Controller #{token}",
      role: :operator
    )
    @request.session[:user_id] = @user.id

    @household = Household.create!(name: "Test Home #{token}", owner: @user)
    HouseholdMembership.create!(household: @household, user: @user)

    seed_camera_capabilities(8)
  end

  # ── Basic page smoke tests (catch render errors before they hit production) ─

  test "home index renders successfully for operator" do
    get :index
    assert_response :success
    assert_match "Home Dashboard", @response.body
  end

  test "home index renders camera tile titles" do
    get :index
    assert_match "CAM 1", @response.body
    assert_match "CAM 8", @response.body
    assert_match snapshot_home_camera_path("cam_1"), @response.body
  end

  test "home index seeds exactly one dashboard with 8 tiles on first visit" do
    get :index

    dashboard = Dashboard.find_by!(user: @user, context: "home", name: "Home Dashboard")

    assert_equal 1, ServiceProvider.where(key: @provider_key).count
    assert_equal 1, ServiceConnection.where(key: @connection_key).count
    assert_equal 8, dashboard.dashboard_tiles.count
    assert_equal 8, dashboard.dashboard_widgets.count
  end

  test "home index re-visiting does not duplicate tiles" do
    get :index
    get :index

    dashboard = Dashboard.find_by!(user: @user, context: "home", name: "Home Dashboard")

    assert_equal 8, dashboard.dashboard_tiles.count
  end

  test "edit mode renders dashboard editor" do
    get :index, params: { edit: 1 }
    assert_response :success
    assert_match "Add Tile",                          @response.body
    assert_match "Add Widget",                        @response.body
    assert_match "Search Capabilities",               @response.body
    assert_match "Capability Type",                   @response.body
    assert_match "Selected Capability",               @response.body
    assert_match "Service Providers",                 @response.body
    assert_match "Devices and Capabilities",          @response.body
    assert_match "data-controller=\"dashboard-layout\"", @response.body
    assert_match "data-controller=\"widget-picker\"", @response.body
    assert_match "Drag a tile header",                @response.body
  end

  test "empty state shown when dashboard has no tiles" do
    @user.update!(role: :operator)
    Dashboard.fetch_or_create_for!(user: @user, context: :home, name: "Empty Dashboard")
    get :index, params: { dashboard: "Empty Dashboard" }
    assert_response :success
    assert_match "No tiles yet", @response.body
  end

  # ── Admin syncs all four services — tab nav appears ────────────────────────

  test "admin visit provisions three dashboard tabs" do
    @user.update!(role: :admin)

    with_all_stubs do
      get :index
    end

    assert_response :success
    assert_match "Home Dashboard",     @response.body
    assert_match "Finances Dashboard", @response.body
    assert_match "Security Overview",  @response.body
  end

  test "dashboard param selects Finances Dashboard tab" do
    @user.update!(role: :admin)

    with_all_stubs do
      get :index, params: { dashboard: "Finances Dashboard" }
    end

    assert_response :success
    assert_match "Finances Dashboard", @response.body
  end

  test "dashboard param selects Security Overview tab" do
    @user.update!(role: :admin)

    with_all_stubs do
      get :index, params: { dashboard: "Security Overview" }
    end

    assert_response :success
    assert_match "Security Overview", @response.body
  end

  # ── Regression: Ursa campaigns-as-strings must not 500 ────────────────────

  test "ursa campaigns returned as bare strings does not cause 500" do
    @user.update!(role: :admin)

    with_all_stubs(ursa_campaigns: [ "red-team-q2", "internal-audit" ]) do
      get :index
    end

    assert_response :success
    cap = DeviceCapability.find_by(key: "ursa_campaigns")
    assert_not_nil cap, "ursa_campaigns capability should be created"
    assert_equal 0, cap.state_hash["value"]
    assert_equal 2, cap.state_hash.dig("breakdown", "Total")
  end

  # ── Service errors become banners, not 500s ───────────────────────────────

  test "kodiak and ursa errors produce error banners, not 500" do
    @user.update!(role: :admin)

    with_koala_stub do
      with_polar_stub do
        stub_sync(Home::KodiakDeviceSync, raises: KodiakClient::RequestError.new("timeout", status: 503, body: "")) do
          stub_sync(Home::UrsaDeviceSync, raises: UrsaClient::RequestError.new("offline", status: 503, body: "")) do
            get :index
          end
        end
      end
    end

    assert_response :success
    assert_match "Kodiak sync failed", @response.body
    assert_match "Ursa sync failed",   @response.body
  end

  test "polar error produces polar error banner, not 500" do
    @user.update!(role: :admin)

    with_koala_stub do
      stub_sync(Home::PolarDeviceSync, raises: PolarClient::RequestError.new("polar down", status: 503, body: "")) do
        stub_sync(Home::KodiakDeviceSync, raises: KodiakClient::RequestError.new("skip", status: 503, body: "")) do
          stub_sync(Home::UrsaDeviceSync, raises: UrsaClient::RequestError.new("skip", status: 503, body: "")) do
            get :index
          end
        end
      end
    end

    assert_response :success
    assert_match "Polar sync failed", @response.body
  end

  # ── Access control ─────────────────────────────────────────────────────────

  test "viewer can access home dashboard" do
    @user.update!(role: :viewer)
    get :index
    assert_response :success
  end

  test "unauthenticated request redirects to login" do
    @request.session[:user_id] = nil
    get :index
    assert_redirected_to login_path
  end

  test "non-household-member is denied" do
    token = SecureRandom.hex(6)
    other = User.create!(
      email: "dashboard-controller-other-#{token}@example.com",
      google_uid: "dashboard-controller-other-#{token}",
      name: "Dashboard Controller Other #{token}",
      role: :operator
    )
    @request.session[:user_id] = other.id
    get :index
    assert_redirected_to login_path
  end

  private

  # ── Data helpers ───────────────────────────────────────────────────────────

  def seed_camera_capabilities(count)
    provider = ServiceProvider.create!(key: @provider_key, name: "Koala", provider_type: "hybrid")
    connection = ServiceConnection.create!(
      service_provider: provider, key: @connection_key, name: "Koala Main",
      adapter: "koala", credential_strategy: "environment",
      status: "online", base_url: "http://192.168.86.53:8082"
    )
    (1..count).each do |i|
      device = Device.create!(
        service_connection: connection, user: @user,
        key: "koala-camera-cam_#{i}", name: "CAM #{i}",
        category: "camera", source_kind: "physical",
        source_identifier: "cam_#{i}", status: "available"
      )
      DeviceCapability.create!(
        device: device, key: "primary_feed", name: "CAM #{i} Feed",
        capability_type: "camera_feed",
        configuration: { "camera_id" => "cam_#{i}" },
        state: { "status" => "available" }
      )
    end
  end

  # ── Stub helpers ───────────────────────────────────────────────────────────

  def with_all_stubs(ursa_campaigns: [ { "id" => "c1", "status" => "active" } ], &block)
    with_koala_stub do
      with_polar_stub do
        with_kodiak_stub do
          with_ursa_stub(campaigns: ursa_campaigns, &block)
        end
      end
    end
  end

  def with_koala_stub(&block)
    fake = Object.new
    fake.define_singleton_method(:list_cameras) { { "data" => { "cameras" => [] } } }
    stub_client(KoalaClient, instance: fake, &block)
  end

  def with_polar_stub(&block)
    fake = Object.new
    fake.define_singleton_method(:latest_readings) { [] }
    fake.define_singleton_method(:station_health) do
      { "station_id" => "homelab", "overall" => "ok",
        "generated_at" => Time.current.iso8601, "components" => [] }
    end
    stub_client(PolarClient, instance: fake, &block)
  end

  def with_kodiak_stub(&block)
    fake = Object.new
    fake.define_singleton_method(:engine_status) do
      { "running" => true, "mode" => "paper", "dry_run" => false, "strategy_count" => 2 }
    end
    fake.define_singleton_method(:portfolio_summary) do
      { "equity" => 100_000.0, "cash" => 25_000.0, "buying_power" => 50_000.0,
        "day_pnl" => 312.50, "unrealized_pl" => 1_200.0 }
    end
    stub_client(KodiakClient, instance: fake, &block)
  end

  def with_ursa_stub(campaigns: [ { "id" => "c1", "status" => "active" } ], &block)
    fake = Object.new
    fake.define_singleton_method(:get_json) do |path, **|
      path.include?("campaigns") ? { "campaigns" => campaigns } : { "sessions" => [] }
    end
    stub_client(UrsaClient, instance: fake, &block)
  end

  def stub_client(klass, instance: nil, raises: nil)
    original = klass.method(:new)
    klass.define_singleton_method(:new) { |*| raises ? raise(raises) : instance }
    yield
  ensure
    klass.define_singleton_method(:new) { |*args, **kwargs, &blk| original.call(*args, **kwargs, &blk) }
  end

  # Stubs a sync service's #sync! to raise, and temporarily sets env vars so
  # the controller's guard (return if ENV[...].blank?) doesn't skip the sync.
  def stub_sync(klass, raises:, &block)
    env_keys = {
      Home::KodiakDeviceSync => { "KODIAK_URL" => "http://test-kodiak", "KODIAK_TOKEN" => "test-token" },
      Home::PolarDeviceSync  => { "POLAR_URL"  => "http://test-polar",  "POLAR_TOKEN"  => "test-token" },
      Home::UrsaDeviceSync   => { "URSA_URL"   => "http://test-ursa",   "URSA_TOKEN"   => "test-token" }
    }

    original_new = klass.method(:new)
    fake = Object.new
    fake.define_singleton_method(:sync!) { raise raises }
    klass.define_singleton_method(:new) { |**| fake }

    saved = (env_keys[klass] || {}).transform_values { |_| ENV[_] }
    (env_keys[klass] || {}).each { |k, v| ENV[k] = v }

    block.call
  ensure
    klass.define_singleton_method(:new) { |*args, **kwargs, &blk| original_new.call(*args, **kwargs, &blk) }
    saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV.store(k, v) }
  end
end
