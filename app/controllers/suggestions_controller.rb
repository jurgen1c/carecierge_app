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

  def save
    ensure_gesture!
    feedback = suggestion_feedback
    authorize feedback, :save?
    feedback.save_for_later!
    render_suggestions
  end

  def complete
    ensure_gesture!
    feedback = suggestion_feedback
    authorize feedback, :complete?
    feedback.mark_acted!
    render_suggestions
  end

  def act
    feedback = suggestion_feedback
    authorize feedback, :act?
    redirect_to new_reminder_path(
      relationship_profile_id: @relationship_profile.id,
      suggestion: @suggestion.fingerprint,
      gesture: @suggestion.variation
    )
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user.relationship_profiles.active.friendly.find(params[:relationship_profile_id])
  end

  def set_suggestion
    @suggestions_as_of = Time.current
    @suggestions = Suggestions::ForProfile.call(
      relationship_profile: @relationship_profile,
      as_of: @suggestions_as_of,
      gesture_variation: params[:gesture]
    )
    @suggestion = @suggestions
      .find { |suggestion| suggestion.fingerprint == params[:id] }
    raise ActiveRecord::RecordNotFound unless @suggestion
  end

  def suggestion_feedback
    current_user.suggestion_feedbacks.find_or_initialize_by(fingerprint: @suggestion.fingerprint).tap do |feedback|
      feedback.relationship_profile = @relationship_profile
    end
  end

  def ensure_gesture!
    raise ActiveRecord::RecordNotFound unless @suggestion.gesture?
  end

  def render_suggestions
    feedbacks = current_user.suggestion_feedbacks
      .where(fingerprint: @suggestions.map(&:fingerprint))
      .index_by(&:fingerprint)
    visible_suggestions = @suggestions.reject { |suggestion| feedbacks[suggestion.fingerprint]&.hidden? }
    selected_suggestion = visible_suggestions.find { |suggestion| suggestion.fingerprint == @suggestion.fingerprint } || visible_suggestions.first
    next_gesture_variation = Suggestions::NextGestureVariation.call(
      user: current_user,
      relationship_profile: @relationship_profile,
      suggestion: selected_suggestion,
      as_of: @suggestions_as_of
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "suggestions_section",
          partial: "suggestions/section",
          locals: {
            relationship_profile: @relationship_profile,
            suggestions: visible_suggestions,
            selected_suggestion:,
            feedbacks:,
            next_gesture_variation:
          }
        )
      end
      format.html do
        redirect_to relationship_profile_path(
          @relationship_profile,
          suggestion: selected_suggestion&.fingerprint,
          gesture: @suggestion.variation
        )
      end
    end
  end

  def not_found
    head :not_found
  end
end
