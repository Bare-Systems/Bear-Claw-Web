module Admin
  class InvitesController < ApplicationController
    before_action -> { require_role(:admin) }

    def index
      @home = Household.first
      unless @home
        redirect_to admin_root_path, alert: "No household exists yet. Run db:seed first." and return
      end
      @invites = @home.invites.includes(:created_by, :accepted_by).order(created_at: :desc)
      @invite  = Invite.new
    end

    def create
      @home = Household.first
      unless @home
        redirect_to admin_root_path, alert: "No household exists yet. Run db:seed first." and return
      end
      @invite = @home.invites.build(invite_params.merge(created_by: current_user))

      days = params.dig(:invite, :expires_in_days).to_i
      @invite.expires_at = days > 0 ? days.days.from_now : nil

      if @invite.save
        invite_link = accept_invite_url(token: @invite.token)
        redirect_to admin_invites_path, notice: "Invite created! Link: #{invite_link}"
      else
        @invites = @home.invites.includes(:created_by, :accepted_by).order(created_at: :desc)
        render :index, status: :unprocessable_entity
      end
    end

    def destroy
      invite = Household.first.invites.find(params[:id])
      invite.update!(status: "revoked")
      redirect_to admin_invites_path, notice: "Invite revoked."
    end

    private

    def invite_params
      params.require(:invite).permit(:email, :max_uses)
    end
  end
end
