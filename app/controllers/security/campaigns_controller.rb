module Security
  class CampaignsController < BaseController
    def index
      @campaigns = ursa_client.get_json("/api/v1/campaigns")["campaigns"]
    end

    def show
      @campaign = load_campaign(params[:id])
    end

    def playbooks
      @playbooks = ursa_client.get_json("/api/v1/campaigns/playbooks")["playbooks"]
    end

    def save_playbook
      items = params[:items].to_s.lines.map do |line|
        title, details, owner, due_offset_days = line.split("|", 4).map { |value| value.to_s.strip }
        next if title.blank?

        {
          title: title,
          details: details,
          owner: owner,
          due_offset_days: due_offset_days.presence
        }
      end.compact

      ursa_client.post_json("/api/v1/campaigns/playbooks", payload: {
        name: params[:name],
        description: params[:description],
        items: items
      })
      redirect_to playbooks_security_campaigns_path, notice: "Playbook saved."
    end

    def delete_playbook
      ursa_client.delete_json("/api/v1/campaigns/playbooks/#{CGI.escape(params[:name].to_s)}")
      redirect_to playbooks_security_campaigns_path, notice: "Playbook deleted."
    end

    def add_note
      ursa_client.post_json("/api/v1/campaigns/#{params[:id]}/notes", payload: { note: params[:note] })
      redirect_to security_campaign_path(params[:id]), notice: "Campaign note added."
    end

    def delete_note
      ursa_client.delete_json("/api/v1/campaigns/#{params[:id]}/notes/#{params[:note_id]}")
      redirect_to security_campaign_path(params[:id]), notice: "Campaign note deleted."
    end

    def add_checklist_item
      ursa_client.post_json("/api/v1/campaigns/#{params[:id]}/checklist", payload: {
        title: params[:title],
        details: params[:details],
        owner: params[:owner],
        due_at: params[:due_at]
      })
      redirect_to security_campaign_path(params[:id]), notice: "Checklist item added."
    end

    def update_checklist_item
      ursa_client.patch_json("/api/v1/campaigns/#{params[:id]}/checklist/#{params[:item_id]}", payload: {
        status: params[:status],
        title: params[:title],
        details: params[:details],
        owner: params[:owner],
        due_at: params[:due_at]
      }.compact_blank)
      redirect_to security_campaign_path(params[:id]), notice: "Checklist item updated."
    end

    def delete_checklist_item
      ursa_client.delete_json("/api/v1/campaigns/#{params[:id]}/checklist/#{params[:item_id]}")
      redirect_to security_campaign_path(params[:id]), notice: "Checklist item deleted."
    end

    def bulk_update_checklist
      ursa_client.patch_json("/api/v1/campaigns/#{params[:id]}/checklist", payload: {
        action_status: params[:action_status],
        status_filter: params[:status_filter],
        owner_filter: params[:owner_filter],
        q_filter: params[:q_filter],
        sort_filter: params[:sort_filter]
      })
      redirect_to security_campaign_path(params[:id]), notice: "Checklist items updated."
    end

    def apply_playbook
      ursa_client.post_json("/api/v1/campaigns/#{params[:id]}/playbook/apply", payload: {
        playbook: params[:playbook],
        owner: params[:owner]
      })
      redirect_to security_campaign_path(params[:id]), notice: "Playbook applied."
    end

    def snapshot_playbook
      ursa_client.post_json("/api/v1/campaigns/#{params[:id]}/playbook/snapshot", payload: {
        playbook_name: params[:playbook_name],
        description: params[:description],
        only_open: params[:only_open].present?
      })
      redirect_to security_campaign_path(params[:id]), notice: "Playbook snapshot saved."
    end

    def handoff
      payload = ursa_client.get_json("/api/v1/campaigns/#{params[:id]}/handoff")
      send_data JSON.pretty_generate(payload), filename: "campaign_handoff_#{params[:id]}.json", type: "application/json"
    end

    private

    def load_campaign(campaign_name)
      ursa_client.get_json("/api/v1/campaigns/#{campaign_name}", params: {
        status: params[:status],
        owner: params[:owner],
        q: params[:q],
        sort: params[:sort]
      })
    end
  end
end
