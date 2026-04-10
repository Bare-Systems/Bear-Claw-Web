module Finances
  class BaseController < ApplicationController
    before_action -> { require_role(:operator, :admin) }

    private

    def kodiak_client
      @kodiak_client ||= KodiakClient.new(
        base_url: ENV.fetch("KODIAK_URL", "http://192.168.86.53:6702"),
        token:    ENV.fetch("KODIAK_TOKEN", "")
      )
    end
  end
end
