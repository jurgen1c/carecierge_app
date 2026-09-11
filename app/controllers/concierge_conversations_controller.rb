class ConciergeConversationsController < ApplicationController
  include PrivacyVaultSession
  include ConciergeWorkspace

  before_action -> { response.headers["Cache-Control"] = "no-store" }
  before_action :set_conversation, only: %i[show transcript update destroy]
  rate_limit to: 20, within: 1.minute, by: -> { current_user.id }, only: :create

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def index
    authorize ConciergeConversation, :index?
    @conversation = current_user.concierge_conversations.new(relationship_profile: selected_profile)
    prepare_concierge_workspace
    render_context_page if context_page_request?
  end

  def show
    prepare_concierge_workspace
    return render_context_page if context_page_request?
    render :index, formats: [ :html ], content_type: "text/html"
  end

  def transcript
    prepare_concierge_workspace
    render :show, formats: [ :turbo_stream ], content_type: "text/vnd.turbo-stream.html"
  end

  def create
    @conversation = Concierge::Start.call(user: current_user, **submission_attributes,
      relationship_profile_id: message_params[:relationship_profile_id])
    redirect_to concierge_conversation_path(@conversation), status: :see_other
  rescue ActiveRecord::RecordInvalid, Concierge::Error => error
    @conversation = current_user.concierge_conversations.new(relationship_profile: selected_profile)
    @content = message_params[:content]
    @error_code = error.is_a?(Concierge::Error) ? error.code : "invalid_message"
    prepare_concierge_workspace
    render :index, status: :unprocessable_content
  end

  def update
    authorize @conversation, :update?
    @conversation.update!(relationship_profile: selected_profile)
    redirect_to concierge_conversation_path(@conversation), status: :see_other
  end

  def destroy
    return head :unprocessable_content unless params[:confirm_delete] == "1"

    @conversation.destroy!
    redirect_to concierge_conversations_path, status: :see_other
  end

  private

  def set_conversation
    @conversation = policy_scope(ConciergeConversation).find(params[:id])
    authorize @conversation, action_name == "transcript" ? :show? : "#{action_name}?"
  end

  def selected_profile
    id = params[:relationship_profile_id].presence || message_params[:relationship_profile_id].presence
    current_user.relationship_profiles.active.find(id) if id
  end

  def message_params
    params.fetch(:concierge_message, ActionController::Parameters.new).permit(:content, :request_key,
      :relationship_profile_id, private_note_ids: [], vault_item_ids: [])
  end

  def submission_attributes
    { content: message_params[:content], request_key: message_params[:request_key], locale: I18n.locale,
      context: message_params.slice(:private_note_ids, :vault_item_ids).to_h,
      vault_lease: privacy_vault_lease }
  end
end
