require "rails_helper"

RSpec.describe DataExports::Snapshot do
  it "exports purchase logistics within the owned gift and removes them with the gift" do
    gift = create(:gift)
    plan = GiftPurchasePlan.create!(gift:, shipping_notes: "Private logistics", options: [ { "vendor" => "Bookshop", "url" => "https://books.example" } ])
    other = GiftPurchasePlan.create!(gift: create(:gift), shipping_notes: "Another owner")
    snapshot = described_class.new(user: gift.relationship_profile.user).to_h
    exported = snapshot.dig("relationship_profiles", 0, "gifts", 0, "purchase_plan")
    expect(exported).to include("shipping_notes" => "Private logistics", "options" => plan.options)
    expect(exported).not_to have_key("lock_version")
    expect(snapshot.to_json).not_to include("Another owner")
    expect { gift.destroy! }.to change(GiftPurchasePlan, :count).by(-1)
    expect(other.reload).to be_persisted
  end
end
