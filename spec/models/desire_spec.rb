# == Schema Information
#
# Table name: desires
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  captured_on             :date
#  category                :string           not null
#  notes                   :text
#  source                  :string           default("manual"), not null
#  status                  :string           default("active"), not null
#  title                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_desires_on_relationship_profile_id                  (relationship_profile_id)
#  index_desires_on_relationship_profile_id_and_captured_on  (relationship_profile_id,captured_on)
#  index_desires_on_relationship_profile_id_and_category     (relationship_profile_id,category)
#  index_desires_on_relationship_profile_id_and_status       (relationship_profile_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
require "rails_helper"

RSpec.describe Desire, type: :model do
  describe "relationship profile desire lists" do
    it "excludes archived desires from active suggestion inputs" do
      profile = create(:relationship_profile)
      active = create(:desire, relationship_profile: profile, title: "Active desire", status: "active")
      planned = create(:desire, relationship_profile: profile, title: "Planned desire", status: "planned")
      archived = create(:desire, relationship_profile: profile, title: "Archived desire", status: "archived")

      expect(profile.active_desires).to contain_exactly(active, planned)
      expect(profile.active_desires).not_to include(archived)
    end
  end

  describe "#suggestion_contexts" do
    it "exposes downstream planning contexts based on category" do
      desire = build(:desire, category: "gift")

      expect(desire.suggestion_contexts).to eq(%w[gift birthday gesture])
    end
  end

  describe ".editable_status_options" do
    it "keeps terminal statuses out of the generic edit form" do
      option_values = described_class.editable_status_options.map(&:second)

      expect(option_values).to eq(%w[active planned])
      expect(option_values).not_to include("fulfilled", "archived")
    end
  end

  describe "#fulfill!" do
    it "marks the desire fulfilled and records history" do
      desire = create(:desire)

      expect do
        desire.fulfill!(fulfilled_on: Date.new(2026, 7, 7), notes: "Handled thoughtfully.")
      end.to change(desire.fulfillments, :count).by(1)

      expect(desire).to be_fulfilled
      expect(desire.fulfillments.sole).to have_attributes(fulfilled_on: Date.new(2026, 7, 7), notes: "Handled thoughtfully.")
    end
  end
end
