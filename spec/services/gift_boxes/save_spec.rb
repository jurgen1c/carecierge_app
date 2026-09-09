require "rails_helper"

RSpec.describe GiftBoxes::Save do
  it "advances the whole-box version when only an item changes, even within the same clock tick" do
    Timecop.freeze(Time.zone.local(2026, 9, 8, 10)) do
      box = create(:relationship_profile).gift_boxes.create!(name: "Reading box", occasion: "Birthday")
      item = box.items.create!(name: "Book")
      version = box.lock_version
      described_class.call(box:, attributes: { items_attributes: [ { id: item.id, completed: true } ] }, expected_version: version.to_s)
      expect(item.reload).to be_completed
      expect(box.reload.lock_version).to be > version
      expect do
        described_class.call(box:, attributes: { notes: "Stale edit" }, expected_version: version.to_s)
      end.to raise_error(ActiveRecord::StaleObjectError)
      expect(box.reload.notes).not_to eq("Stale edit")
    end
  end
end
