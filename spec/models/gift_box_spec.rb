require "rails_helper"
RSpec.describe GiftBox, type: :model do
  let(:box) { described_class.new(relationship_profile: create(:relationship_profile), name: "Private bundle", occasion: "Birthday", budget: "30.25") }
  it "encrypts all personal content and sums only known costs using decimals" do
    box.items.build(name: "Book", notes: "Personal fit", vendor: "Local shop", purchase_url: "https://example.test/item", cost: "20.10")
    box.items.build(name: "Wrapping")
    box.save!
    expect(box.reload.known_total).to eq(BigDecimal("20.10"))
    expect(box.remaining_budget).to eq(BigDecimal("10.15"))
    expect(box.read_attribute_before_type_cast(:name)).not_to include("Private bundle")
    expect(box.items.first.read_attribute_before_type_cast(:notes)).not_to include("Personal fit")
  end
  it "rejects malformed, negative and overprecision amounts and unsafe URLs" do
    [ "bad", "-1", "1.999", "1e3", "10000000000" ].each do |amount|
      box.budget = amount
      expect(box).not_to be_valid
      expect(box.errors[:budget]).to be_present
    end
    box.budget = "30.25"
    item = box.items.build(name: "Book", cost: "1.999", purchase_url: "javascript:alert(1)")
    expect(box).not_to be_valid
    expect(item.errors[:cost]).to be_present
    expect(item.errors[:purchase_url]).to be_present
    item.cost = "20.10"
    [ "https://user:pass@example.test", "invalid url" ].each do |url|
      item.purchase_url = url
      expect(item).not_to be_valid
    end
  end
  it "removes items explicitly and deletes remaining items with their box" do
    box.items.build(name: "Book")
    box.items.build(name: "Wrapping")
    box.save!
    box.update!(items_attributes: [ { id: box.items.first.id, _destroy: "1" } ])
    expect(box.items.reload.size).to eq(1)
    expect { box.destroy! }.to change(GiftBoxItem, :count).by(-1)
  end
end
