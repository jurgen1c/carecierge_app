module ConciergeHelper
  def concierge_history_title(conversation)
    first_turn = @history_first_turns[conversation.id]
    if first_turn && !concierge_turn_available?(first_turn)
      return t("concierge.new_conversation")
    end
    conversation.title.presence || t("concierge.new_conversation")
  end

  def concierge_page_path(**pages)
    options = { history_page: @history_pagy&.page, turn_page: @turns_pagy&.page,
      private_notes_page: @private_notes_pagy&.page, vault_items_page: @vault_items_pagy&.page,
      relationship_profile_id: (@conversation.relationship_profile_id unless @conversation.persisted?) }.merge(pages)
    @conversation.persisted? ? concierge_conversation_path(@conversation, **options) : concierge_conversations_path(**options)
  end

  def concierge_turn_available?(turn)
    Concierge::Context.verify!(turn: concierge_read_turn(turn))
    true
  rescue Concierge::Error, ActiveRecord::RecordNotFound
    false
  end

  def concierge_read_turn(turn)
    return turn if Array(turn.context["vault_item_ids"]).empty?
    raise Concierge::VaultLocked unless privacy_vault_unlocked?

    Concierge::ReadTurn.new(turn:, vault_lease: privacy_vault_lease)
  end

  def concierge_source_path(source)
    profile_id = source["relationship_profile_id"]
    case source["record_type"]
    when "Suggestion"
      relationship_profile_path(profile_id, suggestion: source.fetch("id"), gesture: source["variation"], anchor: "suggestions_section")
    when "ApprovalRequest"
      status = case source["state"]
      when "deferred" then "deferred"
      when *ApprovalRequest::TERMINAL_STATUSES then "completed"
      else "pending"
      end
      approvals_path(id: source.fetch("id"), status:)
    when "RelationshipPreference"
      relationship_profile_path(profile_id, section: "about", anchor: "persona_source_relationship_preference_#{source.fetch('id')}")
    when "RelationshipNote"
      relationship_profile_path(profile_id, section: "about", anchor: "profile-about")
    when "ContactCadence"
      relationship_profile_path(profile_id, section: "moments", anchor: "contact_rhythm_section")
    when "GiftRecommendation"
      relationship_profile_path(profile_id, section: "ideas", anchor: "gift-recommendations")
    when "GiftPurchasePlan"
      relationship_profile_gift_purchase_plan_path(profile_id, source.fetch("gift_id"))
    when "GiftBox"
      relationship_profile_gift_box_path(profile_id, source.fetch("id"))
    when "GiftBoxItem"
      relationship_profile_gift_box_path(profile_id, source.fetch("gift_box_id"))
    when "Vendor"
      vendors_path(vendor_id: source.fetch("id"), event_plan_id: source["event_plan_id"])
    when "VendorShortlist"
      vendor_shortlist_path(source.fetch("id"))
    when "VendorOption"
      vendor_shortlist_path(source.fetch("shortlist_id"))
    when "VendorQuote"
      event_plan_vendor_quotes_path(source.fetch("event_plan_id"))
    when "Booking"
      event_plan_bookings_path(source.fetch("event_plan_id"))
    when "RelationshipProfile"
      relationship_profile_path(source.fetch("id"))
    when "MemoryRecord"
      relationship_profile_path(profile_id, anchor: "memory_record_#{source.fetch('id')}")
    when "EventPlan"
      event_plan_path(source.fetch("id"))
    when "PlanTask"
      event_plan_path(source.fetch("event_plan_id"), anchor: "plan_task_#{source.fetch('id')}")
    when "Reminder"
      reminders_path(anchor: "reminder_#{source.fetch('id')}")
    when "ExtractedMemory"
      relationship_profile_path(profile_id, memory_proposal: source.fetch("id"), anchor: "memory-review")
    when "DraftRevision"
      relationship_profile_path(profile_id, section: "ideas", anchor: "message-drafting")
    when "RelationshipBriefing"
      relationship_profile_path(profile_id, section: "ideas", anchor: "relationship-briefing")
    when "BackupOption"
      event_plan_path(source.fetch("event_plan_id"), anchor: "backup-options")
    when "PersonalTouchItem"
      if source["event_plan_id"]
        event_plan_path(source["event_plan_id"], anchor: "personal-touch-checklist")
      else
        relationship_profile_path(profile_id, anchor: "personal-touch-#{source['important_date_id']}")
      end
    else
      if Concierge::Sources::ASSOCIATIONS.key?(source["record_type"]) || source["record_type"] == "ContactCadence"
        relationship_profile_path(profile_id, anchor: "#{source['record_type'].underscore}_#{source.fetch('id')}")
      end
    end
  end

  def concierge_busy?(turns)
    turns.any? { |turn| (turn.state.in?(%w[queued running]) && !turn.stalled?) || turn.actions.any?(&:busy?) }
  end

  def concierge_submission_path(conversation)
    conversation.persisted? ? concierge_conversation_concierge_turns_path(conversation) : concierge_conversations_path
  end
end
