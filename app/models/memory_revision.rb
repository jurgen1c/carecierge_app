# == Schema Information
#
# Table name: memory_revisions
# Database name: primary
#
#  id               :uuid             not null, primary key
#  note             :text
#  previous_body    :text             not null
#  revised_body     :text             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  memory_record_id :uuid             not null
#  user_id          :uuid
#
# Indexes
#
#  index_memory_revisions_on_memory_record_id                 (memory_record_id)
#  index_memory_revisions_on_memory_record_id_and_created_at  (memory_record_id,created_at)
#  index_memory_revisions_on_user_id                          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (memory_record_id => memory_records.id)
#  fk_rails_...  (user_id => users.id)
#
class MemoryRevision < ApplicationRecord
  belongs_to :memory_record
  belongs_to :user, optional: true

  before_validation :normalize_text_fields

  validates :previous_body, presence: true
  validates :revised_body, presence: true

  private

  def normalize_text_fields
    self.previous_body = previous_body.to_s.strip
    self.revised_body = revised_body.to_s.strip
    self.note = note.to_s.strip.presence
  end
end
