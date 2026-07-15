# == Schema Information
#
# Table name: conversation_recaps
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  body                    :text             not null
#  capture_source          :string           default("typed"), not null
#  extraction_approved_at  :datetime
#  extraction_requested_at :datetime
#  extraction_status       :string           default("not_requested"), not null
#  occurred_at             :datetime         not null
#  title                   :string           not null
#  transcript              :text
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_capture_source_0d8af56d63     (relationship_profile_id,capture_source)
#  idx_on_relationship_profile_id_extraction_status_90ce435e9b  (relationship_profile_id,extraction_status)
#  idx_on_relationship_profile_id_occurred_at_74ae112d81        (relationship_profile_id,occurred_at)
#  index_conversation_recaps_on_relationship_profile_id         (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
require "rails_helper"

RSpec.describe ConversationRecap, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  describe "validations" do
    it "requires supported capture sources and extraction statuses" do
      recap = build(:conversation_recap, capture_source: "unknown", extraction_status: "approved")

      expect(recap).not_to be_valid
      expect(recap.errors[:capture_source]).to include("is not included in the list")
      expect(recap.errors[:extraction_status]).to include("is not included in the list")
    end

    it "normalizes title, body, and transcript text" do
      recap = build(
        :conversation_recap,
        title: "  Lunch   with   David  ",
        body: "  David is thinking about changing jobs.  ",
        transcript: "  Raw transcript line.  "
      )

      recap.valid?

      expect(recap.title).to eq("Lunch with David")
      expect(recap.body).to eq("David is thinking about changing jobs.")
      expect(recap.transcript).to eq("Raw transcript line.")
    end

    it "defaults the occurred time before validation" do
      travel_to Time.zone.local(2026, 7, 9, 8, 30, 0) do
        recap = build(:conversation_recap, occurred_at: nil)

        recap.valid?

        expect(recap.occurred_at).to eq(Time.zone.local(2026, 7, 9, 8, 30, 0))
      end
    end

    it "rejects future occurrence times at the source boundary" do
      now = Time.zone.local(2026, 7, 14, 12)

      travel_to now do
        recap = build(:conversation_recap, occurred_at: now + 1.second)

        expect(recap).not_to be_valid
        expect(recap.errors[:occurred_at]).to include("can't be in the future")
      end
    end
  end

  describe ".ordered" do
    it "orders newest recaps first with stable title and ID ties" do
      profile = create(:relationship_profile)
      older = create(:conversation_recap, relationship_profile: profile, title: "Older", occurred_at: Time.zone.local(2026, 7, 1, 10, 0, 0))
      same_time_b = create(:conversation_recap, relationship_profile: profile, title: "Zoo lunch", occurred_at: Time.zone.local(2026, 7, 8, 10, 0, 0))
      same_time_a = create(:conversation_recap, relationship_profile: profile, title: "Book chat", occurred_at: Time.zone.local(2026, 7, 8, 10, 0, 0))
      same_title_b = create(:conversation_recap, id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", relationship_profile: profile, title: "Same recap", occurred_at: same_time_a.occurred_at)
      same_title_a = create(:conversation_recap, id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", relationship_profile: profile, title: "Same recap", occurred_at: same_time_a.occurred_at)
      newer = create(:conversation_recap, relationship_profile: profile, title: "Newest", occurred_at: Time.zone.local(2026, 7, 9, 10, 0, 0))

      expect(profile.conversation_recaps.ordered).to eq([ newer, same_time_a, same_title_a, same_title_b, same_time_b, older ])
    end
  end

  describe "#request_memory_extraction" do
    it "preserves the pending request through validation errors" do
      recap = build(:conversation_recap, title: "", request_memory_extraction: "1")

      recap.valid?

      expect(recap.extraction_status).to eq("not_requested")
      expect(recap.request_memory_extraction).to eq("1")
      expect(recap.extraction_requested_at).to be_nil
    end

    it "marks the recap as requested on save without approving extracted memory" do
      travel_to Time.zone.local(2026, 7, 9, 9, 0, 0) do
        recap = build(:conversation_recap, request_memory_extraction: "1")

        recap.save!

        expect(recap.extraction_status).to eq("requested")
        expect(recap.extraction_requested_at).to eq(Time.zone.local(2026, 7, 9, 9, 0, 0))
        expect(recap.extraction_approved_at).to be_nil
      end
    end
  end
end
