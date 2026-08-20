module RelationshipProfileShowWorkspace
  MESSAGE_DRAFT_REVISION_PAGE_SIZE = 10
  SOCIAL_CONTEXT_PAGE_SIZE = 5

  private

  def prepare_relationship_profile_show(invalid_social_context_note: nil)
    unless @relationship_profile.archived?
      prepare_social_context_ledger(invalid_social_context_note:)
      prepare_relationship_briefing_workspace
      prepare_message_draft_workspace
    end
    @relationship_persona = RelationshipPersona.new(relationship_profile: @relationship_profile)
    @mood_notes = @relationship_profile.mood_notes.ordered.to_a
    @interactions = @relationship_profile.interactions.includes(:source).ordered.limit(10).to_a
    suggestions_as_of = Time.current
    suggestions = Suggestions::ForProfile.call(
      relationship_profile: @relationship_profile,
      as_of: suggestions_as_of,
      mood_notes: @mood_notes,
      important_dates: @relationship_profile.important_dates,
      interactions: @interactions,
      gesture_variation: params[:gesture],
      social_context_notes: @social_context_source_notes
    )
    @suggestion_feedbacks = current_user.suggestion_feedbacks
      .where(fingerprint: suggestions.map(&:fingerprint))
      .index_by(&:fingerprint)
    @suggestions = suggestions.reject { |suggestion| @suggestion_feedbacks[suggestion.fingerprint]&.hidden? }
    @selected_suggestion = @suggestions.find { |suggestion| suggestion.fingerprint == params[:suggestion] }
    @selected_suggestion ||= @suggestions.find(&:gesture?) if params[:suggestion_type] == "spontaneous"
    @selected_suggestion ||= @suggestions.first
    @next_gesture_variation = Suggestions::NextGestureVariation.call(
      user: current_user,
      relationship_profile: @relationship_profile,
      suggestion: @selected_suggestion,
      as_of: suggestions_as_of,
      mood_notes: @mood_notes,
      important_dates: @relationship_profile.important_dates,
      interactions: @interactions,
      social_context_notes: @social_context_source_notes
    )
    @timeline_type = params[:timeline_type].to_s.in?(TimelineEntry::ENTRY_TYPES) ? params[:timeline_type].to_s : nil
    @relationship_reminders = @relationship_profile.reminders.active.by_effective_delivery.limit(5).to_a
    @conversation_recaps = @relationship_profile.conversation_recaps.ordered.includes(:extracted_memories).to_a
    @extracted_memories = @conversation_recaps.flat_map(&:extracted_memories).sort_by do |memory|
      [ memory.pending? ? 0 : 1, memory.created_at, memory.id ]
    end
    pending_memories = @extracted_memories.select(&:pending?)
    @selected_extracted_memory = pending_memories.find { |memory| memory.id == params[:memory_proposal] } || pending_memories.first
    @memory_extraction_enabled = FeatureFlag.enabled?("ai_memory_extraction", user: current_user, environment: Rails.env)
  end

  def prepare_message_draft_workspace
    @message_draft = @relationship_profile.message_draft
    if @message_draft
      @message_draft_revisions_pagy, @message_draft_revisions = pagy(
        :offset,
        @message_draft.draft_revisions,
        limit: MESSAGE_DRAFT_REVISION_PAGE_SIZE,
        page_key: "draft_page"
      )
    else
      @message_draft_revisions = []
      @message_draft_revisions_pagy = nil
    end
    @message_context_categories = MessageDrafts::ContextBuilder.new(
      relationship_profile: @relationship_profile,
      social_context_notes: @social_context_source_notes
    ).call.categories
    @message_private_notes_available = @relationship_profile.relationship_notes
      .where(private: true)
      .where.missing(:privacy_vault_item)
      .exists?
    @message_vault_items_available = @relationship_profile.privacy_vault_items.exists?
    @message_vault_unlocked = privacy_vault_unlocked?
  end

  def prepare_relationship_briefing_workspace
    @relationship_briefing = @relationship_profile.relationship_briefings.visible.recent_first.first
    @briefing_private_notes_available = @relationship_profile.relationship_notes
      .where(private: true)
      .where.missing(:privacy_vault_item)
      .exists?
    @briefing_vault_items_available = @relationship_profile.privacy_vault_items.exists?
    @briefing_vault_unlocked = privacy_vault_unlocked?
    @relationship_briefing_form_state ||= {}
  end

  def prepare_social_context_ledger(invalid_social_context_note: nil)
    @social_context_notes_pagy, @social_context_notes = pagy(
      :offset,
      @relationship_profile.social_context_notes.with_rich_text_body_and_embeds.recent_first,
      limit: SOCIAL_CONTEXT_PAGE_SIZE,
      page_key: "social_context_page"
    )
    @social_context_notes = @social_context_notes.to_a

    if invalid_social_context_note&.persisted?
      @social_context_notes.map! do |note|
        note.id == invalid_social_context_note.id ? invalid_social_context_note : note
      end
      @new_social_context_note = @relationship_profile.social_context_notes.new
    else
      @new_social_context_note = invalid_social_context_note || @relationship_profile.social_context_notes.new
    end

    @social_context_source_notes = @relationship_profile.social_context_notes
      .downstream_sources
      .to_a

    @social_context_analysis_permission = AutomationPermission.decision_for(
      user: current_user,
      capability: "analyze_uploaded_social_content",
      relationship_profile: @relationship_profile
    )
  end
end
