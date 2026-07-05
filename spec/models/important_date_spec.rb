# == Schema Information
#
# Table name: important_dates
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  date_type               :string           not null
#  importance_level        :string           default("normal"), not null
#  notes                   :text
#  recurrence              :string           default("none"), not null
#  reminder_schedule       :string           default("none"), not null
#  starts_on               :date             not null
#  title                   :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_importance_level_a07d6afa11      (relationship_profile_id,importance_level)
#  index_important_dates_on_relationship_profile_id                (relationship_profile_id)
#  index_important_dates_on_relationship_profile_id_and_date_type  (relationship_profile_id,date_type)
#  index_important_dates_on_relationship_profile_id_and_starts_on  (relationship_profile_id,starts_on)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
require "rails_helper"

RSpec.describe ImportantDate, type: :model do
  describe "validations" do
    it "requires a supported date type, date, recurrence, importance level, and reminder schedule" do
      important_date = build(
        :important_date,
        date_type: "invalid",
        starts_on: nil,
        recurrence: "invalid",
        importance_level: "invalid",
        reminder_schedule: "invalid"
      )

      expect(important_date).not_to be_valid
      expect(important_date.errors[:date_type]).to include("is not included in the list")
      expect(important_date.errors[:starts_on]).to include("can't be blank")
      expect(important_date.errors[:recurrence]).to include("is not included in the list")
      expect(important_date.errors[:importance_level]).to include("is not included in the list")
      expect(important_date.errors[:reminder_schedule]).to include("is not included in the list")
    end
  end

  describe "#next_occurrence_on" do
    it "returns the next yearly occurrence after the reference date" do
      important_date = build(:important_date, starts_on: Date.new(2020, 4, 12), recurrence: "yearly")

      expect(important_date.next_occurrence_on(as_of: Date.new(2026, 4, 1))).to eq(Date.new(2026, 4, 12))
      expect(important_date.next_occurrence_on(as_of: Date.new(2026, 4, 13))).to eq(Date.new(2027, 4, 12))
    end

    it "does not return a yearly occurrence before the first start date" do
      important_date = build(:important_date, starts_on: Date.new(2027, 12, 25), recurrence: "yearly")

      expect(important_date.next_occurrence_on(as_of: Date.new(2026, 1, 1))).to eq(Date.new(2027, 12, 25))
    end

    it "returns nil for past one-time dates" do
      important_date = build(:important_date, starts_on: Date.new(2026, 4, 12), recurrence: "none")

      expect(important_date.next_occurrence_on(as_of: Date.new(2026, 4, 13))).to be_nil
    end

    it "returns the next monthly occurrence after the reference date" do
      important_date = build(:important_date, starts_on: Date.new(2026, 1, 31), recurrence: "monthly")

      expect(important_date.next_occurrence_on(as_of: Date.new(2026, 2, 1))).to eq(Date.new(2026, 2, 28))
      expect(important_date.next_occurrence_on(as_of: Date.new(2026, 3, 1))).to eq(Date.new(2026, 3, 31))
    end

    it "does not return a monthly occurrence before the first start date" do
      important_date = build(:important_date, starts_on: Date.new(2026, 12, 25), recurrence: "monthly")

      expect(important_date.next_occurrence_on(as_of: Date.new(2026, 7, 4))).to eq(Date.new(2026, 12, 25))
    end

    it "returns the next weekly occurrence after the reference date" do
      important_date = build(:important_date, starts_on: Date.new(2026, 7, 6), recurrence: "weekly")

      expect(important_date.next_occurrence_on(as_of: Date.new(2026, 7, 4))).to eq(Date.new(2026, 7, 6))
      expect(important_date.next_occurrence_on(as_of: Date.new(2026, 7, 8))).to eq(Date.new(2026, 7, 13))
    end
  end

  describe "#planning_prompt" do
    it "returns a softer planning prompt for upcoming dates" do
      important_date = build(:important_date, date_type: "birthday", starts_on: Date.new(2026, 7, 25), recurrence: "yearly")

      expect(important_date.planning_prompt(as_of: Date.new(2026, 7, 4))).to eq("Plan ahead for this birthday.")
    end

    it "does not prompt for dates outside the planning window" do
      important_date = build(:important_date, starts_on: Date.new(2026, 12, 25), recurrence: "none")

      expect(important_date.planning_prompt(as_of: Date.new(2026, 7, 4))).to be_nil
    end
  end
end
