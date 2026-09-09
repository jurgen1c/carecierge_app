# == Schema Information
#
# Table name: concierge_actions
# Database name: primary
#
#  id           :uuid             not null, primary key
#  arguments    :text
#  decided_at   :datetime
#  expires_at   :datetime
#  fingerprint  :string(64)       not null
#  name         :string           not null
#  precondition :text
#  result       :text
#  state        :string           default("pending"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  turn_id      :uuid             not null
#
# Indexes
#
#  index_concierge_actions_on_turn_id_and_fingerprint  (turn_id,fingerprint) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (turn_id => concierge_turns.id)
#
require "digest"

class ConciergeAction < ApplicationRecord
  STATES = %w[pending awaiting_approval approved running succeeded failed rejected].freeze
  MAX_ATTEMPTS = 3
  MAX_RUNTIME = 5.minutes
  SOURCE_ORIGIN_NAMES = %w[drafts.generate drafts.update drafts.restore briefings.generate gift_ideas.generate gift_ideas.alternative plan_ideas.generate backups.generate].freeze
  SOURCE_TYPES = %w[DraftRevision RelationshipBriefing GiftRecommendation PlanTask BackupOption].freeze

  belongs_to :turn, class_name: "ConciergeTurn", inverse_of: :actions

  serialize :arguments, coder: JSON
  serialize :result, coder: JSON
  serialize :precondition, coder: JSON
  encrypts :arguments, :result, :precondition
  before_save :advance_execution_order, if: -> { new_record? || will_save_change_to_result? }
  before_save :index_generated_sources, if: -> { new_record? || will_save_change_to_result? || will_save_change_to_state? || will_save_change_to_name? }

  validates :name, presence: true, length: { maximum: 100 }
  validates :fingerprint, presence: true, length: { is: 64 }, uniqueness: { scope: :turn_id }
  validates :state, inclusion: { in: STATES }

  def stalled?
    state.in?(%w[pending approved running]) && (started_at || updated_at) < MAX_RUNTIME.ago
  end

  def retryable?
    attempts < MAX_ATTEMPTS && (state == "failed" || stalled?)
  end

  def busy?
    state.in?(%w[pending approved running]) && !stalled?
  end

  def arguments
    super || {}
  end

  def result
    super || {}
  end

  def precondition
    super || {}
  end

  def self.generated_source_key(type:, id:)
    Digest::SHA256.hexdigest("#{type}:#{id}")
  end

  private

  def index_generated_sources
    self.source_keys = []
    return unless state == "succeeded" && name.in?(SOURCE_ORIGIN_NAMES)

    references = Array(result["records"]) + [ result["record"] ].compact
    self.source_keys = references.filter_map do |reference|
      next unless reference.is_a?(Hash) && reference["record_type"].in?(SOURCE_TYPES) && reference["id"].is_a?(String)
      self.class.generated_source_key(type: reference["record_type"], id: reference["id"])
    end.uniq
  end

  def advance_execution_order
    turn.with_lock do
      self.execution_order = turn.actions.maximum(:execution_order).to_i + 1
    end
  end
end
