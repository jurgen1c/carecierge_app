require "base64"

module DataExports
  class Snapshot
    def initialize(user:, relationship_profile: nil, include_sensitive: false, include_file_contents: true)
      @user = user
      @relationship_profile = relationship_profile
      @include_sensitive = include_sensitive
      @include_file_contents = include_file_contents
    end

    def to_h
      {
        "exported_at" => Time.current.iso8601,
        "scope" => relationship_profile ? "relationship_profile" : "account",
        "account" => account_attributes,
        "relationship_profiles" => profiles.map { |profile| profile_attributes(profile) }
      }.merge(approval_data).merge(account_data)
    end

    private

    attr_reader :user, :relationship_profile, :include_sensitive, :include_file_contents

    def profiles
      @profiles ||= if relationship_profile
        [ relationship_profile ]
      else
        user.relationship_profiles.with_discarded.order(:created_at).to_a
      end
    end

    def account_attributes
      user.attributes.slice("id", "email", "created_at", "updated_at")
    end

    def account_data
      return {} if relationship_profile

      {
        "notification_preference" => attributes_for(user.notification_preference),
        "relationship_tags" => records(user.relationship_tags),
        "relationship_groups" => records(user.relationship_groups),
        "vendors" => user.vendors.ordered.includes(:event_plan_vendors).map { |vendor| vendor_attributes(vendor) },
        "feed_item_states" => records(user.feed_item_states, except: %w[user_id]),
        "reminders" => user.reminders.includes(:reminder_deliveries).map { |reminder| reminder_attributes(reminder) },
        "digest_deliveries" => records(user.digest_deliveries),
        "vault_access_events" => records(user.vault_access_events, except: %w[user_id]),
        "notifications" => records(user.notifications, except: %w[recipient_type recipient_id]),
        "automation_permissions" => records(user.automation_permissions),
        "automation_permission_changes" => records(user.automation_permission_changes),
        "audit_events" => records(user.audit_events, except: %w[user_id actor_id]),
        "deletion_requests" => records(user.deletion_requests, except: %w[user_id account_digest])
      }
    end

    def approval_data
      scope = user.approval_requests
      if relationship_profile
        extracted = scope.where(subject_type: "ExtractedMemory", subject_id: relationship_profile.extracted_memories.select(:id))
        memories = scope.where(subject_type: "MemoryRecord", subject_id: relationship_profile.memory_records.select(:id))
        scope = extracted.or(memories)
      end

      {
        "approval_requests" => scope.includes(:approval_decisions).map { |request| approval_request_attributes(request) }
      }
    end

    def profile_attributes(profile)
      attributes_for(profile, except: %w[user_id type message_draft_generation_version briefing_generation_version gift_recommendation_generation_version]).merge(
        "relationship_type" => profile.type,
        "relationship_type_label" => profile.relationship_type_label,
        "contact_methods" => records(profile.contact_methods),
        "relationship_taggings" => records(profile.relationship_taggings),
        "relationship_group_memberships" => records(profile.relationship_group_memberships),
        "relationship_notification_preference" => attributes_for(relationship_notification_preferences[profile.id]),
        "relationship_notes" => profile.relationship_notes.map { |note| note_attributes(note) },
        "relationship_preferences" => records(profile.relationship_preferences),
        "relationship_field_values" => records(profile.relationship_field_values),
        "important_dates" => records(profile.important_dates),
        "gifts" => records(profile.gifts),
        "gift_recommendations" => profile.gift_recommendations.recent_first.map { |recommendation| gift_recommendation_attributes(recommendation) },
        "event_plans" => event_plans_for(profile).map { |plan| event_plan_attributes(plan) },
        "vendor_shortlists" => vendor_shortlists_for(profile).map { |shortlist| vendor_shortlist_attributes(shortlist) },
        "personal_touch_checklists" => profile.personal_touch_checklists.includes(:personal_touch_items).order(:created_at, :id).map do |checklist|
          personal_touch_checklist_attributes(checklist)
        end,
        "memory_records" => profile.memory_records.map { |memory| memory_attributes(memory) },
        "social_context_notes" => profile.social_context_notes.with_rich_text_body_and_embeds.map { |note| social_context_note_attributes(note) },
        "message_draft" => message_draft_attributes(profile.message_draft),
        "relationship_briefings" => profile.relationship_briefings.recent_first.map { |briefing| relationship_briefing_attributes(briefing) },
        "conversation_recaps" => profile.conversation_recaps.map { |recap| conversation_recap_attributes(recap) },
        "extracted_memories" => records(profile.extracted_memories, except: %w[reviewed_by_id]),
        "mood_notes" => records(profile.mood_notes),
        "timeline_entries" => records(profile.timeline_entries),
        "commitments" => records(profile.commitments),
        "desires" => profile.desires.map { |desire| desire_attributes(desire) },
        "contact_cadence" => attributes_for(profile.contact_cadence),
        "interactions" => records(profile.interactions),
        "suggestion_feedbacks" => records(profile.suggestion_feedbacks, except: %w[user_id relationship_profile_id]),
        "reminders" => profile.reminders.includes(:reminder_deliveries).map { |reminder| reminder_attributes(reminder) },
        "privacy_vault_items" => privacy_vault_items(profile)
      )
    end

    def note_attributes(note)
      attributes_for(note).merge("body" => note.body.to_plain_text)
    end

    def memory_attributes(memory)
      attributes_for(memory).merge("memory_revisions" => records(memory.memory_revisions, except: %w[user_id]))
    end

    def social_context_note_attributes(note)
      attributes_for(note, except: %w[lock_version]).merge(
        "body" => note.body.to_plain_text,
        "uploaded_images" => note.image_blobs.map { |blob| blob_attributes(blob) }
      )
    end

    def message_draft_attributes(draft)
      return unless draft

      attributes_for(draft, except: %w[user_id relationship_profile_id]).merge(
        "tone" => draft.effective_tone,
        "formality" => draft.effective_formality,
        "draft_revisions" => records(draft.draft_revisions.reorder(:position), except: %w[message_draft_id])
      )
    end

    def relationship_briefing_attributes(briefing)
      attributes_for(briefing, except: %w[user_id relationship_profile_id lock_version])
    end

    def gift_recommendation_attributes(recommendation)
      attributes_for(recommendation, except: %w[user_id relationship_profile_id lock_version])
    end

    def event_plan_attributes(plan)
      attributes_for(
        plan,
        except: %w[user_id relationship_profile_id generation_version lock_version]
      ).merge(
        "plan_tasks" => plan.plan_tasks.map do |task|
          attributes_for(task, except: %w[event_plan_id lock_version])
        end,
        "vendors" => plan.vendors.map { |vendor| vendor_attributes(vendor) },
        "backup_plans" => plan.backup_plans.map { |backup_plan| backup_plan_attributes(backup_plan) }
      )
    end

    def vendor_attributes(vendor)
      event_plan_ids = vendor.event_plan_vendors.map(&:event_plan_id)
      event_plan_ids.select! { |id| id.in?(exported_event_plan_ids) } if exported_event_plan_ids

      attributes_for(vendor, except: %w[user_id]).merge(
        "event_plan_ids" => event_plan_ids.sort
      )
    end

    def vendor_shortlists_for(profile)
      profile.vendor_shortlists.recent_first.includes(vendor_options: { vendor: :event_plan_vendors })
    end

    def vendor_shortlist_attributes(shortlist)
      attributes_for(shortlist, except: %w[user_id relationship_profile_id lock_version]).merge(
        "vendor_options" => shortlist.vendor_options.map do |option|
          attributes_for(option, except: %w[vendor_shortlist_id vendor_id lock_version]).merge(
            "vendor" => vendor_attributes(option.vendor)
          )
        end
      )
    end

    def event_plans_for(profile)
      @event_plans_by_profile_id ||= {}
      @event_plans_by_profile_id[profile.id] ||= profile.event_plans
        .ordered
        .includes(:plan_tasks, { vendors: :event_plan_vendors }, backup_plans: :backup_options)
        .to_a
    end

    def exported_event_plan_ids
      return unless relationship_profile

      @exported_event_plan_ids ||= event_plans_for(relationship_profile).map(&:id).to_set
    end

    def backup_plan_attributes(backup_plan)
      attributes_for(
        backup_plan,
        except: %w[user_id event_plan_id event_plan_generation_version context_fingerprint lock_version]
      ).merge(
        "source_context" => exportable_source_context(backup_plan.source_context),
        "backup_options" => backup_plan.backup_options.map do |option|
          attributes_for(option, except: %w[backup_plan_id lock_version])
        end
      )
    end

    def exportable_source_context(source_context)
      source_context.map do |source|
        source["sensitive"] && !include_sensitive ? source.except("content") : source
      end
    end

    def personal_touch_checklist_attributes(checklist)
      attributes_for(
        checklist,
        except: %w[relationship_profile_id event_plan_id important_date_id]
      ).merge(
        "moment_type" => checklist.event_plan_id ? "EventPlan" : "ImportantDate",
        "moment_id" => checklist.event_plan_id || checklist.important_date_id,
        "items" => records(checklist.personal_touch_items, except: %w[personal_touch_checklist_id])
      )
    end

    def conversation_recap_attributes(recap)
      attributes_for(recap).merge("audio_recording" => attachment_attributes(recap.audio_recording))
    end

    def attachment_attributes(attachment)
      return unless attachment.attached?

      blob_attributes(attachment.blob)
    end

    def blob_attributes(blob)
      metadata = {
        "filename" => blob.filename.to_s,
        "content_type" => blob.content_type,
        "byte_size" => blob.byte_size,
        "checksum" => blob.checksum
      }
      return metadata unless include_file_contents

      metadata.merge("encoding" => "base64", "data" => Base64.strict_encode64(blob.download))
    end

    def desire_attributes(desire)
      attributes_for(desire).merge("fulfillments" => records(desire.fulfillments))
    end

    def reminder_attributes(reminder)
      attributes_for(reminder).merge(
        "reminder_deliveries" => records(reminder.reminder_deliveries, except: %w[lease_token error_message])
      )
    end

    def privacy_vault_items(profile)
      return [] unless include_sensitive

      profile.privacy_vault_items.map do |item|
        attributes_for(item, except: %w[payload]).merge("payload" => item.payload)
      end
    end

    def relationship_notification_preferences
      @relationship_notification_preferences ||= RelationshipNotificationPreference
        .where(relationship_profile_id: profiles.map(&:id))
        .index_by(&:relationship_profile_id)
    end

    def approval_request_attributes(request)
      attributes_for(request, except: %w[user_id lock_version]).merge(
        "approval_decisions" => records(request.approval_decisions, except: %w[user_id approval_request_id])
      )
    end

    def records(scope, except: [])
      scope.map { |record| attributes_for(record, except:) }
    end

    def attributes_for(record, except: [])
      return nil unless record

      record.attributes.except(*except)
    end
  end
end
