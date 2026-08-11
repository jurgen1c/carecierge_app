require "rails_helper"

# == Schema Information
#
# Table name: draft_revisions
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  content            :text             not null
#  context_categories :jsonb            not null
#  origin             :string           not null
#  position           :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  message_draft_id   :uuid             not null
#
# Indexes
#
#  index_draft_revisions_on_message_draft_id               (message_draft_id)
#  index_draft_revisions_on_message_draft_id_and_position  (message_draft_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (message_draft_id => message_drafts.id) ON DELETE => cascade
#
RSpec.describe DraftRevision, type: :model do
  it "rejects unsupported origins and context categories" do
    revision = build(:draft_revision, origin: "sent", context_categories: %w[profile contact_details])

    expect(revision).not_to be_valid
    expect(revision.errors[:origin]).to be_present
    expect(revision.errors[:context_categories]).to be_present
  end

  it "cannot be changed after persistence" do
    revision = create(:draft_revision)

    expect { revision.update!(content: "Changed in place") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect(revision.reload.content).not_to eq("Changed in place")
  end
end
