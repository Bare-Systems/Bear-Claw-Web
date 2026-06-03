require "test_helper"

class Finances::DashboardControllerTest < ActionController::TestCase
  tests Finances::DashboardController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)
    @request.session[:user_id] = @user.id
  end

  test "renders signal monitoring sections on the finances dashboard" do
    fake = Object.new
    fake.define_singleton_method(:engine_status) { { "running" => true } }
    fake.define_singleton_method(:portfolio_summary) do
      { "equity" => 100_000.0, "cash" => 25_000.0, "buying_power" => 50_000.0 }
    end
    fake.define_singleton_method(:positions) { [] }
    fake.define_singleton_method(:market_signal_overview) do
      {
        "enabled" => true,
        "poll_interval_seconds" => 300,
        "recent_window_hours" => 24,
        "active_source_count" => 2,
        "direct_alert_count" => 3,
        "needs_inference_count" => 1
      }
    end
    fake.define_singleton_method(:market_signal_alerts) do |**|
      [
        {
          "bucket" => "direct",
          "action" => "buy",
          "title" => "BUY NVDA from @signaldesk",
          "source_label" => "@signaldesk",
          "reason" => "Matched regex rule 'nvda-buy'",
          "text" => "We added $NVDA on weakness.",
          "symbol" => "NVDA",
          "observed_at" => 10.minutes.ago.iso8601
        },
        {
          "bucket" => "needs_inference",
          "action" => "needs_inference",
          "title" => "Inference needed from @signaldesk",
          "source_label" => "@signaldesk",
          "text" => "Watching semis again here.",
          "symbol" => "NVDA",
          "observed_at" => 8.minutes.ago.iso8601
        }
      ]
    end
    fake.define_singleton_method(:market_signal_sources) do
      [
        {
          "label" => "@signaldesk",
          "provider" => "x",
          "account" => "@signaldesk",
          "rule_count" => 2,
          "last_success_at" => 5.minutes.ago.iso8601,
          "last_error" => nil
        }
      ]
    end

    original = KodiakClient.method(:new)
    KodiakClient.define_singleton_method(:new) { |*args, **kwargs| fake }

    get :index

    assert_response :success
    assert_match "Direct Signal Alerts", @response.body
    assert_match "Inference Queue", @response.body
    assert_match "Source Health", @response.body
    assert_match "BUY NVDA from @signaldesk", @response.body
    assert_match "@signaldesk", @response.body
  ensure
    KodiakClient.define_singleton_method(:new) { |*args, **kwargs, &blk| original.call(*args, **kwargs, &blk) }
  end
end
