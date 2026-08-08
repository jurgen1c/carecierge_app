class SuggestionsController < ApplicationController
  before_action :set_relationship_profile
  before_action :set_suggestion

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def feedback
    feedback = suggestion_feedback
    authorize feedback, :feedback?
    feedback.record_feedback!(params[:feedback])
    render_suggestions
  end

  def dismiss
    feedback = suggestion_feedback
    authorize feedback, :dismiss?
    feedback.dismiss!
    render_suggestions
  end

  def act
    feedback = suggestion_feedback
    authorize feedback, :act?
    redirect_to new_reminder_path(
      relationship_profile_id: @relationship_profile.id,
      suggestion: @suggestion.fingerprint
    )
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user.relationship_profiles.active.friendly.find(params[:relationship_profile_id])
  end

  def set_suggestion
    @suggestions = Suggestions::ForProfile.call(relationship_profile: @relationship_profile)
    @suggestion = @suggestions
      .find { |suggestion| suggestion.fingerprint == params[:id] }
    raise ActiveRecord::RecordNotFound unless @suggestion
  end

  def suggestion_feedback
    current_user.suggestion_feedbacks.find_or_initialize_by(fingerprint: @suggestion.fingerprint).tap do |feedback|
      feedback.relationship_profile = @relationship_profile
    end
  end

  def render_suggestions
    feedbacks = current_user.suggestion_feedbacks
      .where(fingerprint: @suggestions.map(&:fingerprint))
      .index_by(&:fingerprint)
    visible_suggestions = @suggestions.reject { |suggestion| feedbacks[suggestion.fingerprint]&.hidden? }
    selected_suggestion = visible_suggestions.find { |suggestion| suggestion.fingerprint == @suggestion.fingerprint } || visible_suggestions.first

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "suggestions_section",
          partial: "suggestions/section",
          locals: {
            relationship_profile: @relationship_profile,
            suggestions: visible_suggestions,
            selected_suggestion:,
            feedbacks:
          }
        )
      end
      format.html { redirect_to relationship_profile_path(@relationship_profile, suggestion: selected_suggestion&.fingerprint) }
    end
  end

  def not_found
    head :not_found
  end
end
