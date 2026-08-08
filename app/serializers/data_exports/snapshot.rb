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
      }.merge(account_data)
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
        "reminders" => records(user.reminders),
        "digest_deliveries" => records(user.digest_deliveries),
        "automation_permissions" => records(user.automation_permissions),
        "automation_permission_changes" => records(user.automation_permission_changes),
        "audit_events" => records(user.audit_events, except: %w[user_id actor_id]),
        "deletion_requests" => records(user.deletion_requests, except: %w[user_id account_digest])
      }
    end

    def profile_attributes(profile)
      attributes_for(profile, except: %w[user_id type]).merge(
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
        "memory_records" => profile.memory_records.map { |memory| memory_attributes(memory) },
        "conversation_recaps" => profile.conversation_recaps.map { |recap| conversation_recap_attributes(recap) },
        "mood_notes" => records(profile.mood_notes),
        "timeline_entries" => records(profile.timeline_entries),
        "commitments" => records(profile.commitments),
        "desires" => profile.desires.map { |desire| desire_attributes(desire) },
        "contact_cadence" => attributes_for(profile.contact_cadence),
        "interactions" => records(profile.interactions),
        "reminders" => records(profile.reminders),
        "privacy_vault_items" => privacy_vault_items(profile)
      )
    end

    def note_attributes(note)
      attributes_for(note).merge("body" => note.body.to_plain_text)
    end

    def memory_attributes(memory)
      attributes_for(memory).merge("memory_revisions" => records(memory.memory_revisions, except: %w[user_id]))
    end

    def conversation_recap_attributes(recap)
      attributes_for(recap).merge("audio_recording" => attachment_attributes(recap.audio_recording))
    end

    def attachment_attributes(attachment)
      return unless attachment.attached?

      blob = attachment.blob
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

    def records(scope, except: [])
      scope.map { |record| attributes_for(record, except:) }
    end

    def attributes_for(record, except: [])
      return nil unless record

      record.attributes.except(*except)
    end
  end
end
