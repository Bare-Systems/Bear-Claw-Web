class DashboardChannel < ApplicationCable::Channel
  # Each user streams from their own named channel so broadcasts are
  # scoped to the individual session rather than broadcast to everyone.
  def subscribed
    stream_from "home_dashboard:#{current_user.id}"
    Rails.logger.info("[DashboardChannel] #{current_user.email} subscribed")
  end

  def unsubscribed
    Rails.logger.info("[DashboardChannel] #{current_user.email} unsubscribed")
  end

  # The Stimulus controller calls this action every 30 s while the
  # dashboard tab is open.  It enqueues a background sync so the page
  # stays live without doing any work when nobody is watching.
  def sync
    SyncDashboardJob.perform_later(user_id: current_user.id)
  end
end
