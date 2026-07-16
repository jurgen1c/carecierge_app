# == Schema Information
#
# Table name: digest_deliveries
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  channel            :string           not null
#  dispatched_at      :datetime
#  email_delivered_at :datetime
#  enqueued_at        :datetime
#  error_message      :text
#  handed_off_at      :datetime
#  mode               :string           not null
#  scheduled_for      :datetime         not null
#  status             :string           default("pending"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  user_id            :uuid             not null
#
# Indexes
#
#  index_digest_deliveries_on_recoverable_lease    (enqueued_at) WHERE ((status)::text = ANY ((ARRAY['pending'::character varying, 'dispatching'::character varying])::text[]))
#  index_digest_deliveries_on_user_and_occurrence  (user_id,scheduled_for) UNIQUE
#  index_digest_deliveries_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class DigestDelivery < ApplicationRecord
  CHANNELS = %w[email in_app].freeze
  MODES = %w[daily weekly].freeze
  STATUSES = %w[pending dispatching dispatched skipped failed cancelled].freeze

  belongs_to :user
  has_many :noticed_events, as: :record, class_name: "Noticed::Event", dependent: :destroy

  validates :channel, inclusion: { in: CHANNELS }
  validates :mode, inclusion: { in: MODES }
  validates :scheduled_for, presence: true, uniqueness: { scope: :user_id }
  validates :status, inclusion: { in: STATUSES }

  scope :recoverable, ->(before:) {
    where(status: "pending", enqueued_at: nil)
      .or(where(status: %w[pending dispatching], enqueued_at: ..before))
  }

  STATUSES.each { |value| define_method("#{value}?") { status == value } }

  def recoverable?(before:)
    (pending? && (enqueued_at.nil? || enqueued_at <= before)) ||
      (dispatching? && enqueued_at.present? && enqueued_at <= before)
  end

  def with_processing_lock
    acquired = false
    result = false

    self.class.connection_pool.with_connection do |connection|
      lock_expression = "hashtextextended(#{connection.quote(id)}, 0)"
      acquired = ActiveModel::Type::Boolean.new.cast(
        connection.select_value("SELECT pg_try_advisory_lock(#{lock_expression})")
      )
      next unless acquired

      begin
        result = yield
      ensure
        connection.select_value("SELECT pg_advisory_unlock(#{lock_expression})")
      end
    end

    result
  end
end
