# == Schema Information
#
# Table name: desire_fulfillments
# Database name: primary
#
#  id           :uuid             not null, primary key
#  fulfilled_on :date             not null
#  notes        :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  desire_id    :uuid             not null
#
# Indexes
#
#  index_desire_fulfillments_on_desire_id                   (desire_id)
#  index_desire_fulfillments_on_desire_id_and_fulfilled_on  (desire_id,fulfilled_on)
#
# Foreign Keys
#
#  fk_rails_...  (desire_id => desires.id)
#
class DesireFulfillment < ApplicationRecord
  belongs_to :desire

  before_validation :normalize_notes

  validates :fulfilled_on, presence: true

  scope :ordered, -> { order(fulfilled_on: :desc, created_at: :desc) }

  private

  def normalize_notes
    self.notes = notes.to_s.strip.presence
  end
end
