class ApprovalRequestsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def index
    authorize ApprovalRequest
    ApprovalQueue::Synchronize.call(user: current_user)
    response.headers["Cache-Control"] = "no-store"
    @owner_time_zone = OwnerLocalCalendar.time_zone_for(user: current_user)

    @status = params[:status].to_s.in?(%w[pending deferred completed]) ? params[:status].to_s : "pending"
    scope = approval_scope
    @pagy, @approval_requests = pagy(:offset, scope, limit: 25)
    @selected_request = selected_request(scope)
    preload_subject_context
    @item = ApprovalQueue::Item.new(approval_request: @selected_request) if @selected_request
  end

  def update
    approval_request = current_user.approval_requests.find(params[:id])
    authorize approval_request
    ApprovalDecisions::Apply.call(
      approval_request:,
      actor: current_user,
      decision: decision_params[:decision],
      lock_version: decision_params[:lock_version],
      corrected_title: decision_params[:corrected_title],
      corrected_body: decision_params[:corrected_body],
      deferred_until: decision_params[:deferred_until]
    )

    redirect_to approvals_path(status: "pending"), notice: t("approvals.update.notice.#{decision_params[:decision]}")
  rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError, ArgumentError
    redirect_to approvals_path(status: "pending", id: params[:id], **queue_context), alert: t("approvals.update.error")
  end

  private

  def decision_params
    params.require(:approval_request).permit(:decision, :lock_version, :corrected_title, :corrected_body, :deferred_until)
  end

  def queue_context
    page = Integer(params[:page], exception: false)
    mode = params[:mode].to_s

    {
      page: page&.positive? ? page : nil,
      mode: mode.in?(%w[edit defer]) ? mode : nil
    }
  end

  def scope_name
    { "pending" => :pending_review, "deferred" => :deferred, "completed" => :completed }.fetch(@status)
  end

  def approval_scope
    policy_scope(ApprovalRequest).public_send(scope_name).includes(:subject, :approval_decisions)
  end

  def selected_request(scope)
    return @approval_requests.first if params[:id].blank?

    scope.find_by(id: params[:id]) || @approval_requests.first
  end

  def preload_subject_context
    subjects = (@approval_requests.to_a + [ @selected_request ]).compact.map(&:subject).uniq
    ActiveRecord::Associations::Preloader.new(records: subjects, associations: :relationship_profile).call
    extracted_memories = subjects.grep(ExtractedMemory)
    if extracted_memories.any?
      ActiveRecord::Associations::Preloader.new(
        records: extracted_memories,
        associations: [ :conversation_recap, { canonical_memory_record: :privacy_vault_item } ]
      ).call
    end
  end
end
