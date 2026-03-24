require "test_helper"

class Agent::ChatControllerTest < ActionController::TestCase
  tests Agent::ChatController

  setup do
    @user = User.find_by!(email: users(:one)["email"])
    @user.update!(role: :operator)
    @request.session[:user_id] = @user.id
  end

  test "renders the full chat panel" do
    get :index

    assert_response :success
    assert_match "Start a conversation", @response.body
    assert_match "Message BearClaw", @response.body
    assert_no_match "Open BearClaw chat", @response.body
  end

  test "streams a chat reply" do
    fake_client = Object.new
    fake_client.define_singleton_method(:chat) do |message|
      {
        "message" => {
          "id" => "reply-1",
          "content" => "Agent received: #{message}"
        }
      }
    end

    original_new = BearClawClient.method(:new)
    BearClawClient.define_singleton_method(:new) { |*| fake_client }

    begin
      post :create, params: { message: "check koala" }, format: :turbo_stream
    ensure
      BearClawClient.define_singleton_method(:new) { |*args, **kwargs, &block| original_new.call(*args, **kwargs, &block) }
    end

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, @response.media_type
    assert_match "check koala", @response.body
    assert_match "Agent received: check koala", @response.body
    assert_match "turbo-stream action=\"append\" target=\"chat-messages\"", @response.body
  end
end
