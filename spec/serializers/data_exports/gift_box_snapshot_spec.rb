require "rails_helper"
RSpec.describe DataExports::Snapshot do
  it "exports only the owner's boxes and cascades profile deletion through items" do
    profile = create(:relationship_profile)
    box = profile.gift_boxes.create!(name: "Private bundle", occasion: "Birthday", notes: "Personal note", items_attributes: [ { name: "Book", purchased: true } ])
    create(:relationship_profile).gift_boxes.create!(name: "Other owner", occasion: "Private")
    snapshot = described_class.new(user: profile.user).to_h
    exported = snapshot.dig("relationship_profiles", 0, "gift_boxes", 0)
    expect(exported).to include("notes" => "Personal note")
    expect(exported.fetch("items").first).to include("name" => "Book", "purchased" => true)
    expect(snapshot.to_json).not_to include("Other owner")
    expect { profile.destroy! }.to change(GiftBoxItem, :count).by(-1)
    expect(GiftBox.exists?(box.id)).to be(false)
  end
end
