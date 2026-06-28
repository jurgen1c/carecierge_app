# == Schema Information
#
# Table name: relationship_notes
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  category                :string
#  private                 :boolean          default(FALSE), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_private_777e9fc47b    (relationship_profile_id,private)
#  index_relationship_notes_on_relationship_profile_id  (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
require "rails_helper"

RSpec.describe RelationshipNote, type: :model do
  subject(:note) { build(:relationship_note) }

  it { is_expected.to belong_to(:relationship_profile) }

  it "stores the note body as rich text" do
    note = create(:relationship_note, body: "<p>Remember <strong>travel</strong> timing.</p>")

    expect(note.body.to_plain_text).to include("Remember travel timing.")
    expect(described_class.reflect_on_association(:rich_text_body)).to be_present
  end

  it "requires visible body text" do
    note.body = ""

    expect(note).not_to be_valid
    expect(note.errors[:body]).to include("can't be blank")
  end
end
