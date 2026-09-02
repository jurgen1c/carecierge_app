require "rails_helper"

# == Schema Information
#
# Table name: vendors
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  availability        :text
#  category            :string           not null
#  fit_notes           :text
#  location            :string
#  maximum_price_cents :integer
#  minimum_price_cents :integer
#  name                :string           not null
#  occasion_types      :jsonb            not null
#  preference_tags     :jsonb            not null
#  source_kind         :string           default("manual"), not null
#  source_name         :string
#  source_url          :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  user_id             :uuid             not null
#
# Indexes
#
#  index_vendors_on_occasion_types        (occasion_types) USING gin
#  index_vendors_on_preference_tags       (preference_tags) USING gin
#  index_vendors_on_user_and_lower_name   (user_id, lower((name)::text))
#  index_vendors_on_user_id               (user_id)
#  index_vendors_on_user_id_and_category  (user_id,category)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
RSpec.describe Vendor, type: :model do
  it "normalizes bounded discovery metadata and formats its price range" do
    vendor = build(
      :vendor,
      name: "  Bloom   & Stem ",
      location: "  San Jose  ",
      occasion_types: [ " Birthday ", "birthday", "custom" ],
      preference_tags: [ " Seasonal ", "seasonal", "Quiet" ],
      minimum_price: "125.50",
      maximum_price: "400"
    )

    expect(vendor).to be_valid
    expect(vendor).to have_attributes(
      name: "Bloom & Stem",
      location: "San Jose",
      occasion_types: %w[birthday custom],
      preference_tags: %w[seasonal quiet],
      minimum_price_cents: 12_550,
      maximum_price_cents: 40_000
    )
    expect(vendor.price_range).to eq("$125.50–$400.00")
  end

  it "rejects unsupported categories, reversed prices, and non-http source URLs" do
    vendor = build(
      :vendor,
      category: "unknown",
      minimum_price: "500",
      maximum_price: "100",
      source_kind: "external",
      source_name: "Example",
      source_url: "javascript:alert(1)"
    )

    expect(vendor).not_to be_valid
    expect(vendor.errors).to include(:category, :maximum_price, :source_url)
  end

  it "rejects source URLs containing embedded credentials" do
    vendor = build(
      :vendor,
      source_kind: "external",
      source_name: "Vendor website",
      source_url: "https://private-user:secret@example.com/vendor"
    )

    expect(vendor).not_to be_valid
    expect(vendor.errors).to include(:source_url)
  end

  it "requires named provenance for external records" do
    vendor = build(:vendor, source_kind: "external", source_name: nil, source_url: "https://example.com/vendor")

    expect(vendor).not_to be_valid
    expect(vendor.errors).to include(:source_name)
  end

  it "attaches only to an active event plan owned by the vendor owner" do
    vendor = create(:vendor)
    owned_plan = create(:event_plan, user: vendor.user)
    foreign_plan = create(:event_plan)
    archived_plan = create(:event_plan, user: vendor.user, status: "archived")

    expect(build(:event_plan_vendor, vendor:, event_plan: owned_plan)).to be_valid
    expect(build(:event_plan_vendor, vendor:, event_plan: foreign_plan)).not_to be_valid
    expect(build(:event_plan_vendor, vendor:, event_plan: archived_plan)).not_to be_valid
  end
end
