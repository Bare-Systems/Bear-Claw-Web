module Security
  class GovernanceController < BaseController
    def index
      @filters = params.permit(:status, :campaign, :tag, :risk_level).to_h.reverse_merge("status" => "pending")
      @governance = ursa_client.get_json("/api/v1/governance", params: @filters)
    end

    def approve
      ursa_client.post_json("/api/v1/governance/approvals/#{params[:approval_id]}/approve", payload: { note: params[:note] })
      redirect_back_to security_governance_index_path, notice: "Approval approved."
    end

    def reject
      ursa_client.post_json("/api/v1/governance/approvals/#{params[:approval_id]}/reject", payload: { note: params[:note] })
      redirect_back_to security_governance_index_path, notice: "Approval rejected."
    end

    def bulk_approvals
      ursa_client.post_json("/api/v1/governance/approvals/bulk", payload: {
        campaign: params[:campaign],
        tag: params[:tag],
        risk_level: params[:risk_level],
        decision: params[:decision],
        note: params[:note]
      })
      redirect_back_to security_governance_index_path, notice: "Bulk approval action completed."
    end

    def upsert_policy
      ursa_client.post_json("/api/v1/governance/policy", payload: {
        campaign: params[:campaign],
        max_pending_total: params[:max_pending_total],
        max_pending_high: params[:max_pending_high],
        max_pending_critical: params[:max_pending_critical],
        max_oldest_pending_minutes: params[:max_oldest_pending_minutes],
        note: params[:note]
      })
      redirect_back_to security_governance_index_path, notice: "Policy saved."
    end

    def delete_policy
      ursa_client.delete_json("/api/v1/governance/policy/#{CGI.escape(params[:campaign].to_s)}")
      redirect_back_to security_governance_index_path, notice: "Policy deleted."
    end

    def apply_remediation
      ursa_client.post_json("/api/v1/governance/remediation/apply", payload: {
        campaign: params[:campaign],
        strategy: params[:strategy],
        note: params[:note]
      })
      redirect_back_to security_governance_index_path, notice: "Remediation applied."
    end

    def create_remediation_checklist
      ursa_client.post_json("/api/v1/governance/remediation/checklist", payload: {
        campaign: params[:campaign],
        owner: params[:owner],
        due_in_hours: params[:due_in_hours]
      })
      redirect_back_to security_governance_index_path, notice: "Checklist items created from remediation plan."
    end

    def report
      payload = ursa_client.get_json("/api/v1/governance/report")
      send_data JSON.pretty_generate(payload), filename: "governance_report.json", type: "application/json"
    end
  end
end
