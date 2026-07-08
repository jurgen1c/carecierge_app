# == Schema Information
#
# Table name: memory_records
# Database name: primary
#
#  id                                 :uuid             not null, primary key
#  body                               :text             not null
#  confidence                         :string           default("confirmed"), not null
#  high_impact_automation_approved_at :datetime
#  review_queued_at                   :datetime
#  reviewed_at                        :datetime
#  source                             :string           default("user_confirmed"), not null
#  stale_after                        :date
#  status                             :string           default("active"), not null
#  title                              :string           not null
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  relationship_profile_id            :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_stale_after_ff6eff736b           (relationship_profile_id,stale_after)
#  index_memory_records_on_relationship_profile_id                 (relationship_profile_id)
#  index_memory_records_on_relationship_profile_id_and_confidence  (relationship_profile_id,confidence)
#  index_memory_records_on_relationship_profile_id_and_source      (relationship_profile_id,source)
#  index_memory_records_on_relationship_profile_id_and_status      (relationship_profile_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
require "rails_helper"

RSpec.describe MemoryRecord, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  describe "validations" do
    it "requires supported source, confidence, and status values" do
      record = build(:memory_record, source: "rumor", confidence: "certain", status: "floating")

      expect(record).not_to be_valid
      expect(record.errors[:source]).to be_present
      expect(record.errors[:confidence]).to be_present
      expect(record.errors[:status]).to be_present
    end
  end

  describe "#review_required?" do
    it "is true for stale or queued records" do
      travel_to Time.zone.local(2026, 7, 8, 10, 0, 0) do
        expect(build(:memory_record, status: "needs_review")).to be_review_required
        expect(build(:memory_record, stale_after: Date.yesterday)).to be_review_required
        expect(build(:memory_record, stale_after: Date.tomorrow)).not_to be_review_required
      end
    end
  end

  describe "#high_impact_automation_allowed?" do
    it "blocks low-confidence inferred records until they are approved" do
      record = build(:memory_record, source: "ai_inferred", confidence: "low")

      expect(record).not_to be_high_impact_automation_allowed

      record.high_impact_automation_approved_at = Time.zone.local(2026, 7, 8, 9, 30, 0)

      expect(record).to be_high_impact_automation_allowed
    end

    it "allows confirmed records without separate high-impact approval" do
      record = build(:memory_record, source: "user_confirmed", confidence: "confirmed")

      expect(record).to be_high_impact_automation_allowed
    end
  end

  describe "#queue_review_if_stale!" do
    it "marks stale active records as needing review" do
      travel_to Time.zone.local(2026, 7, 8, 10, 0, 0) do
        record = create(:memory_record, status: "active", stale_after: Date.yesterday)

        record.queue_review_if_stale!

        expect(record.reload).to have_attributes(status: "needs_review", review_queued_at: Time.current)
      end
    end

    it "does not queue current or archived records" do
      travel_to Time.zone.local(2026, 7, 8, 10, 0, 0) do
        current_record = create(:memory_record, status: "active", stale_after: Date.tomorrow)
        archived_record = create(:memory_record, status: "archived", stale_after: Date.yesterday)

        expect(current_record.queue_review_if_stale!).to be(false)
        expect(archived_record.queue_review_if_stale!).to be(false)
        expect(current_record.reload.status).to eq("active")
        expect(archived_record.reload.status).to eq("archived")
      end
    end
  end

  describe "#mark_reviewed!" do
    it "clears stale review state" do
      travel_to Time.zone.local(2026, 7, 8, 10, 0, 0) do
        record = create(:memory_record, status: "needs_review", confidence: "low", stale_after: Date.yesterday, review_queued_at: 1.day.ago)

        record.mark_reviewed!

        expect(record.reload).to have_attributes(
          status: "active",
          confidence: "confirmed",
          stale_after: nil,
          review_queued_at: nil,
          reviewed_at: Time.current
        )
        expect(record).not_to be_review_required
      end
    end
  end
end
