# == Schema Information
#
# Table name: calendar_event_syncs
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  source_fingerprint     :string           not null
#  source_type            :string           not null
#  synced_at              :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  calendar_connection_id :uuid             not null
#  external_event_id      :text             not null
#  source_id              :uuid             not null
#
# Indexes
#
#  index_calendar_event_syncs_on_calendar_connection_id  (calendar_connection_id)
#  index_calendar_event_syncs_on_connection_and_source   (calendar_connection_id,source_type,source_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (calendar_connection_id => calendar_connections.id) ON DELETE => cascade
#
class CalendarEventSync < ApplicationRecord
  SOURCE_TYPES = %w[ImportantDate Reminder EventPlan Booking Commitment].freeze

  belongs_to :calendar_connection
  belongs_to :source, polymorphic: true, optional: true

  encrypts :external_event_id

  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :source_id, :external_event_id, :source_fingerprint, presence: true
  validates :source_id, uniqueness: { scope: %i[calendar_connection_id source_type] }
  validate :source_belongs_to_connection_owner

  private

  def source_belongs_to_connection_owner
    return unless source && calendar_connection

    owner_id = case source
    when ImportantDate, Commitment then source.relationship_profile.user_id
    else source.user_id
    end
    errors.add(:source, :different_owner) unless owner_id == calendar_connection.user_id
  end
end
