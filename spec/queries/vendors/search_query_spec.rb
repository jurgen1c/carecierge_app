require "rails_helper"

RSpec.describe Vendors::SearchQuery do
  it "filters an owner scope by discovery criteria without returning foreign vendors" do
    user = create(:user)
    matching = create(
      :vendor,
      user:,
      name: "Quiet Garden Table",
      category: "restaurant",
      location: "San Jose",
      minimum_price_cents: 20_000,
      availability: "Saturday evening",
      occasion_types: [ "birthday" ],
      preference_tags: [ "quiet", "vegetarian" ]
    )
    create(:vendor, user:, name: "Loud Lunch", category: "restaurant", location: "San Jose", minimum_price_cents: 60_000, maximum_price_cents: 80_000)
    create(:vendor, name: "Foreign Match", category: "restaurant", location: "San Jose", minimum_price_cents: 20_000)

    results = described_class.new(
      user.vendors,
      params: {
        query: "garden",
        category: "restaurant",
        location: "San Jose",
        occasion_type: "birthday",
        preference: "quiet",
        maximum_budget: "300",
        timing: "Saturday"
      }
    ).resolve

    expect(results).to contain_exactly(matching)
  end

  it "defaults occasion and budget to a supplied event plan" do
    user = create(:user)
    plan = create(:event_plan, user:, occasion_type: "birthday", budget_cents: 30_000)
    matching = create(:vendor, user:, occasion_types: [ "birthday" ], minimum_price_cents: 25_000)
    create(:vendor, user:, occasion_types: [ "anniversary" ], minimum_price_cents: 25_000)
    create(:vendor, user:, occasion_types: [ "birthday" ], minimum_price_cents: 40_000, maximum_price_cents: 60_000)

    search = described_class.new(user.vendors, params: {}, event_plan: plan)

    expect(search.resolve).to contain_exactly(matching)
    expect(search.occasion_type).to eq("birthday")
    expect(search.maximum_budget).to eq("300.00")
  end

  it "allows submitted blank filters to clear event plan defaults" do
    user = create(:user)
    plan = create(:event_plan, user:, occasion_type: "birthday", budget_cents: 30_000)
    unfiltered = create(:vendor, user:, occasion_types: [ "anniversary" ], minimum_price_cents: 40_000)

    search = described_class.new(
      user.vendors,
      params: { occasion_type: "", maximum_budget: "" },
      event_plan: plan
    )

    expect(search.resolve).to contain_exactly(unfiltered)
    expect(search.occasion_type).to be_nil
    expect(search.maximum_budget).to be_nil
  end

  it "localizes multi-criterion fit explanations" do
    vendor = create(:vendor, category: "restaurant", location: "San Jose", occasion_types: [ "birthday" ], fit_notes: nil)
    search = described_class.new(
      vendor.user.vendors,
      params: { category: "restaurant", location: "San Jose", occasion_type: "birthday" }
    )

    explanation = I18n.with_locale(:es) { search.explanation_for(vendor) }

    expect(explanation).to eq("Coincide con categoría, ubicación y ocasión.")
  end

  it "does not describe an unknown price as a budget match" do
    vendor = create(:vendor, minimum_price_cents: nil, maximum_price_cents: nil, fit_notes: nil)
    search = described_class.new(vendor.user.vendors, params: { maximum_budget: "300" })

    expect(search.resolve).to contain_exactly(vendor)
    expect(search.explanation_for(vendor)).to eq("Matches your saved research.")
  end

  it "ignores unsupported filter values instead of broadening SQL" do
    vendor = create(:vendor)

    search = described_class.new(vendor.user.vendors, params: { category: "anything' OR true --", maximum_budget: "not-money" })

    expect(search.resolve).to contain_exactly(vendor)
    expect(search.category).to be_nil
    expect(search.maximum_budget).to be_nil
  end
end
