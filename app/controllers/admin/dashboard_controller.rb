module Admin
  class DashboardController < ApplicationController
    def show
      authorize :admin_dashboard, :show?
      response.headers["Cache-Control"] = "no-store"
      return head :no_content if request.headers["X-Sec-Purpose"] == "prefetch"

      AuditEvent.record!(user: current_user, actor: current_user, action: "admin.dashboard.viewed", source: "support")
      @observed_at = Time.current
      query = AdminDashboard::Query.new
      @accounts = query.accounts
      @approvals = query.approvals
      @integrations = query.integrations
      @queue = AdminDashboard::QueueStatus.new.metrics
      @trust = query.trust
    end
  end
end
