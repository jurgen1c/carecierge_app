# == Schema Information
#
# Table name: concierge_turns
# Database name: primary
#
#  id              :uuid             not null, primary key
#  attempts        :integer          default(0), not null
#  content         :text             not null
#  context         :text
#  error_code      :string
#  finished_at     :datetime
#  input_tokens    :integer          default(0), not null
#  locale          :string           default("en"), not null
#  output_tokens   :integer          default(0), not null
#  request_key     :string(64)       not null
#  response        :text
#  run_token       :uuid
#  started_at      :datetime
#  state           :string           default("queued"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  conversation_id :uuid             not null
#
# Indexes
#
#  idx_concierge_turns_history                               (conversation_id,created_at,id)
#  index_concierge_turns_on_conversation_id_and_request_key  (conversation_id,request_key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => concierge_conversations.id)
#
class ConciergeTurn < ApplicationRecord
  MAX_CONTENT_LENGTH = 8_000
  MAX_RESPONSE_LENGTH = 24_000
  MAX_ATTEMPTS = 3
  RUN_TIMEOUT = 5.minutes
  STATES = %w[queued running completed failed].freeze

  belongs_to :conversation, class_name: "ConciergeConversation", inverse_of: :turns
  has_many :actions, class_name: "ConciergeAction", foreign_key: :turn_id, inverse_of: :turn, dependent: :destroy

  serialize :context, coder: JSON
  encrypts :content, :response, :context

  validates :content, presence: true, length: { maximum: MAX_CONTENT_LENGTH }
  validates :response, length: { maximum: MAX_RESPONSE_LENGTH }
  validates :request_key, presence: true, length: { maximum: 64 }, uniqueness: { scope: :conversation_id }
  validates :locale, inclusion: { in: %w[en es] }
  validates :state, inclusion: { in: STATES }

  scope :chronological, -> { order(:created_at, :id) }

  def context
    super || {}
  end

  def referenced_profile_ids
    sources = Array(context["history_sources"]) + actions.flat_map do |action|
      Array(action.result["records"]) + [ action.result["record"] ].compact
    end
    references = sources.filter_map { |source| source["relationship_profile_id"] }
    ([ context["relationship_profile_id"] ] + context.fetch("observed_profiles", {}).keys + references).compact.uniq
  end

  def claim!
    with_lock do
      next unless state == "queued" && attempts < MAX_ATTEMPTS

      token = SecureRandom.uuid
      update!(state: "running", run_token: token, started_at: Time.current, finished_at: nil,
        error_code: nil, attempts: attempts + 1)
      token
    end
  end

  def running_for?(token)
    state == "running" && run_token == token && started_at && started_at > RUN_TIMEOUT.ago
  end

  def append_response!(token:, text:)
    with_lock do
      next false unless running_for?(token)

      update!(response: "#{response}#{text}".first(MAX_RESPONSE_LENGTH))
      true
    end
  end

  def finish!(token:, response:, input_tokens: 0, output_tokens: 0)
    with_lock do
      next false unless running_for?(token)

      update!(state: "completed", response: response.to_s.first(MAX_RESPONSE_LENGTH), finished_at: Time.current,
        input_tokens: input_tokens.to_i.clamp(0, 1_000_000), output_tokens: output_tokens.to_i.clamp(0, 100_000))
      true
    end
  end

  def fail!(token:, error_code: "provider_unavailable")
    with_lock do
      next false unless state == "running" && run_token == token

      update!(state: "failed", error_code:, response: nil, finished_at: Time.current)
      true
    end
  end

  def retry!
    with_lock do
      next false unless attempts < MAX_ATTEMPTS
      next false unless state == "failed" || stalled?

      update!(state: "queued", run_token: nil, response: nil, error_code: nil, finished_at: nil, updated_at: Time.current)
      true
    end
  end

  def stalled?
    (state == "queued" && updated_at <= RUN_TIMEOUT.ago) ||
      (state == "running" && started_at && started_at <= RUN_TIMEOUT.ago)
  end

  def expire_exhausted!
    with_lock do
      next false unless attempts >= MAX_ATTEMPTS && stalled?

      update!(state: "failed", run_token: nil, response: nil, error_code: "execution_expired", finished_at: Time.current)
      true
    end
  end
end
