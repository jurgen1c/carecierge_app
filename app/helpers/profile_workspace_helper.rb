module ProfileWorkspaceHelper
  PROFILE_SECTIONS = %w[moments plans notes about ideas privacy].freeze

  def profile_workspace_sections
    PROFILE_SECTIONS
  end

  def profile_work_preview
    if (reminder = @relationship_reminders.first)
      date = OwnerLocalCalendar.date_for(user: current_user, at: reminder.effective_delivery_at)
      t("profile_workspace.next_reminder", title: reminder.title, date: l(date, format: :long))
    elsif (promise = @relationship_profile.commitments.reject(&:new_record?).find(&:open?))
      t("profile_workspace.open_promise", title: promise.title)
    end
  end

  def profile_section_expanded?(section)
    return true if params[:section] == section

    case section
    when "ideas"
      %w[relationship_briefings message_drafts gift_recommendations].include?(controller_name) ||
        params[:suggestion].present? || params[:suggestion_type].present? || params[:draft_page].present?
    when "notes"
      controller_name == "social_context_notes" || params[:social_context_page].present? ||
        params[:memory_proposal].present? || params[:timeline_type].present?
    else
      false
    end
  end
end
