# == Schema Information
#
# Table name: extracted_memories
# Database name: primary
#
#  id                         :uuid             not null, primary key
#  body                       :text             not null
#  category                   :string           not null
#  confidence                 :string           not null
#  corrected_body             :text
#  corrected_title            :string
#  reviewed_at                :datetime
#  source_excerpt             :text             not null
#  status                     :string           default("pending"), not null
#  title                      :string           not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  canonical_memory_record_id :uuid
#  conversation_recap_id      :uuid             not null
#  relationship_profile_id    :uuid             not null
#  reviewed_by_id             :uuid
#
# Indexes
#
#  index_extracted_memories_on_canonical_memory_record_id          (canonical_memory_record_id) UNIQUE
#  index_extracted_memories_on_conversation_recap_id               (conversation_recap_id)
#  index_extracted_memories_on_conversation_recap_id_and_status    (conversation_recap_id,status)
#  index_extracted_memories_on_relationship_profile_id             (relationship_profile_id)
#  index_extracted_memories_on_relationship_profile_id_and_status  (relationship_profile_id,status)
#  index_extracted_memories_on_reviewed_by_id                      (reviewed_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (canonical_memory_record_id => memory_records.id) ON DELETE => nullify
#  fk_rails_...  (conversation_recap_id => conversation_recaps.id) ON DELETE => cascade
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (reviewed_by_id => users.id) ON DELETE => nullify
#
require "rails_helper"

RSpec.describe ExtractedMemory, type: :model do
  subject(:extracted_memory) { build(:extracted_memory) }

  it "accepts every supported memory category" do
    described_class::CATEGORIES.each do |category|
      extracted_memory.category = category
      expect(extracted_memory).to be_valid
    end
  end

  it "rejects proposals whose source belongs to a different profile" do
    extracted_memory.relationship_profile = create(:relationship_profile)

    expect(extracted_memory).not_to be_valid
    expect(extracted_memory.errors[:conversation_recap]).to be_present
  end

  it "requires correction content only for corrected proposals" do
    extracted_memory.status = "corrected"

    expect(extracted_memory).not_to be_valid
    expect(extracted_memory.errors[:corrected_title]).to be_present
    expect(extracted_memory.errors[:corrected_body]).to be_present
  end
end
