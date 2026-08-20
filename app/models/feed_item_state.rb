# == Schema Information
#
# Table name: feed_item_states
# Database name: primary
#
#  id            :uuid             not null, primary key
#  dismissed_at  :datetime
#  item_key      :string           not null
#  snoozed_until :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :uuid             not null
#
# Indexes
#
#  index_feed_item_states_on_user_id                    (user_id)
#  index_feed_item_states_on_user_id_and_item_key       (user_id,item_key) UNIQUE
#  index_feed_item_states_on_user_id_and_snoozed_until  (user_id,snoozed_until) WHERE (snoozed_until IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class FeedItemState < ApplicationRecord
  MAX_ITEM_KEY_LENGTH = 200
  UNIQUE_INDEX = :index_feed_item_states_on_user_id_and_item_key
  SOURCE_PREFIXES = {
    "Commitment" => "commitment",
    "Desire" => "relationship_goal",
    "Gift" => "gift",
    "ImportantDate" => "important_date",
    "MessageDraft" => "message_draft",
    "Reminder" => "reminder"
  }.freeze
  SUGGESTION_TYPES_BY_SOURCE = {
    "Commitment" => %w[professional_follow_up],
    "ContactCadence" => %w[check_in spontaneous],
    "Desire" => %w[gift plan spontaneous],
    "ImportantDate" => %w[event spontaneous],
    "Interaction" => %w[spontaneous],
    "MemoryRecord" => %w[message],
    "MoodNote" => %w[repair_focused],
    "RelationshipPreference" => %w[message spontaneous],
    "SocialContextNote" => %w[gift message conversation_topic social_reminder]
  }.freeze

  belongs_to :user

  normalizes :item_key, with: ->(value) { value.to_s.strip }

  validates :item_key,
    presence: true,
    length: { maximum: MAX_ITEM_KEY_LENGTH },
    uniqueness: { scope: :user_id }
  validate :active_state_present

  class << self
    def dismiss_for!(user:, item_key:, at: Time.current)
      persist_for!(user:, item_key:, dismissed_at: at, snoozed_until: nil)
    end

    def snooze_for!(user:, item_key:, until_time:)
      raise ArgumentError, "Snooze time must be in the future" unless until_time.present? && until_time > Time.current

      persist_for!(user:, item_key:, dismissed_at: nil, snoozed_until: until_time)
    end

    def delete_for_source!(source)
      source_type = source.class.base_class.name
      owner_id = source_type.in?(%w[RelationshipProfile Reminder]) ? source.user_id : source.relationship_profile.user_id
      scope = where(user_id: owner_id)

      if source_type == "RelationshipProfile"
        prefix = sanitize_sql_like("suggestion:#{source.id}:")
        scope.where("item_key LIKE ?", "#{prefix}%").delete_all
        return
      end

      item_keys = []
      item_keys << "#{SOURCE_PREFIXES[source_type]}:#{source.id}" if SOURCE_PREFIXES.key?(source_type)
      SUGGESTION_TYPES_BY_SOURCE.fetch(source_type, []).each do |suggestion_type|
        variants = suggestion_type == "spontaneous" ? [ nil, *Suggestion::GESTURE_VARIATIONS ] : [ nil ]
        variants.each do |variant|
          fingerprint = Suggestion.fingerprint_for(
            relationship_profile_id: source.relationship_profile_id,
            suggestion_type:,
            source_type:,
            source_id: source.id,
            variant:
          )
          item_keys << "suggestion:#{source.relationship_profile_id}:#{fingerprint}"
        end
      end
      scope.where(item_key: item_keys).delete_all if item_keys.any?
    end

    private

    def persist_for!(user:, item_key:, dismissed_at:, snoozed_until:)
      normalized_key = item_key.to_s.strip
      unless user&.persisted? && normalized_key.present? && normalized_key.length <= MAX_ITEM_KEY_LENGTH
        raise ArgumentError, "Feed item state requires a persisted owner and bounded item key"
      end

      timestamp = Time.current
      upsert(
        {
          user_id: user.id,
          item_key: normalized_key,
          dismissed_at:,
          snoozed_until:,
          created_at: timestamp,
          updated_at: timestamp
        },
        unique_by: UNIQUE_INDEX,
        update_only: %i[dismissed_at snoozed_until]
      )
      user.feed_item_states.find_by!(item_key: normalized_key)
    end
  end

  def hidden?(at: Time.current)
    dismissed_at.present? || snoozed_until.present? && snoozed_until > at
  end

  def dismiss!(at: Time.current)
    update!(dismissed_at: at, snoozed_until: nil)
  end

  def snooze!(until_time:)
    raise ArgumentError, "Snooze time must be in the future" unless until_time.present? && until_time > Time.current

    update!(dismissed_at: nil, snoozed_until: until_time)
  end

  private

  def active_state_present
    errors.add(:base, :blank) if dismissed_at.blank? && snoozed_until.blank?
  end
end
