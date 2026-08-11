module RelationshipSearchesHelper
  def relationship_search_pagination_params(query, page:)
    {
      memory_query: query.q,
      relationship_id: query.relationship_id,
      source: query.source,
      date_range: query.date_range,
      status: query.status,
      page:
    }.compact
  end

  def relationship_search_result_path(result)
    profile = result.relationship_profile
    record = relationship_search_source_record(result.source_record)

    case record
    when RelationshipProfile
      relationship_profile_path(profile)
    when RelationshipNote
      edit_relationship_profile_path(profile, anchor: "relationship-context")
    when RelationshipPreference
      edit_relationship_profile_path(profile, anchor: dom_id(record, :fields))
    when TimelineEntry
      edit_relationship_profile_timeline_entry_path(profile, record)
    when Interaction
      edit_relationship_profile_interaction_path(profile, record)
    when Commitment
      edit_relationship_profile_commitment_path(profile, record)
    when Gift
      edit_relationship_profile_gift_path(profile, record)
    when ImportantDate
      edit_relationship_profile_important_date_path(profile, record)
    when ConversationRecap
      edit_relationship_profile_conversation_recap_path(profile, record)
    when MoodNote
      edit_relationship_profile_mood_note_path(profile, record)
    else
      relationship_profile_path(profile)
    end
  end

  def relationship_search_result_status(result)
    case result.source_record
    when RelationshipProfile then result.source_record.relationship_type_label
    when RelationshipNote then result.title
    when RelationshipPreference then result.source_record.confidence_label
    when TimelineEntry then result.source_record.entry_type_label
    when Interaction then t("relationship_searches.interaction_types.#{result.source_record.interaction_type}")
    when Commitment then result.source_record.status_label
    when Gift then result.source_record.status_label
    when ImportantDate then result.source_record.importance_level_label
    end
  end

  private

  def relationship_search_source_record(record)
    case record
    when TimelineEntry then record.source_record || record
    when Interaction then record.source || record
    else record
    end
  end
end
