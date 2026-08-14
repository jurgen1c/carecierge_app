class SocialContextNotesController < ApplicationController
  include PrivacyVaultSession
  include RelationshipProfileShowWorkspace

  rate_limit to: 5,
    within: 1.minute,
    by: -> { current_user.id },
    only: %i[update analyze],
    if: -> { action_name == "analyze" || analyze_after_save? }

  before_action :set_relationship_profile
  before_action :set_social_context_note, only: %i[update destroy analyze]

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def create
    @social_context_note = @relationship_profile.social_context_notes.new(note_params)
    authorize @social_context_note

    saved = @social_context_note.save_from_user

    if saved
      redirect_to section_path(page: nil), notice: t("social_context_notes.create.notice")
    else
      render_invalid_note(t("social_context_notes.create.invalid"))
    end
  end

  def update
    return unless analysis_permitted?(explicitly_approved: true) if analyze_after_save?

    @social_context_note.update_from_user!(
      note_params,
      approve_interpretation: approve_interpretation?
    )

    if analyze_after_save?
      @analysis_started = true
      analyze_note!(expected_lock_version: @social_context_note.lock_version)
      redirect_to row_path, notice: t("social_context_notes.analyze.notice")
      return
    end

    redirect_to row_path, notice: t("social_context_notes.update.notice")
  rescue ActiveRecord::RecordInvalid
    render_invalid_note(t("social_context_notes.update.invalid"))
  rescue SocialContextNotes::AnalysisError
    redirect_to row_path, alert: t("social_context_notes.analyze.provider_error")
  rescue ActiveRecord::StaleObjectError
    key = @analysis_started ? "social_context_notes.analyze.changed" : "social_context_notes.update.changed"
    redirect_to row_path, alert: t(key)
  end

  def destroy
    blobs = []
    DataDeletions::Perform.call(
      user: current_user,
      request_kind: "social_context_note",
      subject: @social_context_note,
      after_commit: -> { DataDeletions::DeleteBlobs.call(blobs) }
    ) { blobs = @social_context_note.destroy_from_user! }

    redirect_to section_path(page: social_context_page_after_deletion), notice: t("social_context_notes.destroy.notice")
  end

  def analyze
    return unless analysis_permitted?(explicitly_approved: explicit_approval?)

    analyze_note!(expected_lock_version: submitted_lock_version)

    redirect_to row_path, notice: t("social_context_notes.analyze.notice")
  rescue SocialContextNotes::AnalysisError
    redirect_to row_path, alert: t("social_context_notes.analyze.provider_error")
  rescue ActiveRecord::StaleObjectError
    redirect_to row_path, alert: t("social_context_notes.analyze.changed")
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user.relationship_profiles.kept.friendly.find(params[:relationship_profile_id])
  end

  def set_social_context_note
    @social_context_note = @relationship_profile.social_context_notes.find(params[:id])
    authorize @social_context_note, action_name == "analyze" ? :analyze? : nil
  end

  def note_params
    permitted = params.require(:social_context_note).permit(
      :body,
      :interpretation,
      :allow_suggestions,
      :lock_version,
      suggested_uses: []
    )
    if action_name == "update"
      permitted[:lock_version] = Integer(permitted.require(:lock_version), 10)
    elsif permitted.key?(:lock_version)
      permitted[:lock_version] = Integer(permitted[:lock_version], 10)
    end
    permitted[:suggested_uses] = Array(permitted[:suggested_uses]).compact_blank.uniq if permitted.key?(:suggested_uses)
    permitted
  rescue ArgumentError, TypeError
    raise ActionController::BadRequest, "Invalid lock version"
  end

  def approve_interpretation?
    ActiveModel::Type::Boolean.new.cast(params.dig(:social_context_note, :approve_interpretation))
  end

  def explicit_approval?
    ActiveModel::Type::Boolean.new.cast(params[:explicit_approval])
  end

  def analyze_after_save?
    params[:intent] == "analyze"
  end

  def analysis_permitted?(explicitly_approved:)
    permission = AutomationPermission.decision_for(
      user: current_user,
      capability: "analyze_uploaded_social_content",
      relationship_profile: @relationship_profile
    )
    return true if permission.permits_execution?(explicitly_approved:)

    redirect_to analysis_permission_path,
      alert: t("social_context_notes.analyze.permission_required")
    false
  end

  def analysis_permission_path
    edit_automation_permissions_path(
      capability: "analyze_uploaded_social_content",
      anchor: "capability-panel-analyze_uploaded_social_content"
    )
  end

  def analyze_note!(expected_lock_version:)
    SocialContextNotes::Analyze.call(
      actor: current_user,
      note: @social_context_note,
      expected_lock_version:,
      locale: I18n.locale
    )
  end

  def submitted_lock_version
    Integer(params.require(:lock_version), 10)
  rescue ArgumentError, TypeError
    raise ActionController::BadRequest, "Invalid lock version"
  end

  def section_path(page: social_context_page)
    relationship_profile_path(@relationship_profile, social_context_page: page, anchor: "social-context")
  end

  def row_path
    relationship_profile_path(
      @relationship_profile,
      social_context_page:,
      anchor: helpers.dom_id(@social_context_note, :row)
    )
  end

  def social_context_page
    params[:social_context_page].presence
  end

  def social_context_page_after_deletion
    return if social_context_page.blank?

    last_page = [
      (@relationship_profile.social_context_notes.count.to_f / RelationshipProfileShowWorkspace::SOCIAL_CONTEXT_PAGE_SIZE).ceil,
      1
    ].max
    social_context_page.to_i.clamp(1, last_page)
  end

  def render_invalid_note(message)
    flash.now[:alert] = message
    prepare_relationship_profile_show(invalid_social_context_note: @social_context_note)
    render "relationship_profiles/show", status: :unprocessable_content
  end
end
