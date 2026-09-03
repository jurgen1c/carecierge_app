require "rails_helper"

# == Schema Information
#
# Table name: vendor_quotes
# Database name: primary
#
#  id              :uuid             not null, primary key
#  amount_cents    :integer          not null
#  currency        :string           default("USD"), not null
#  decision_due_on :date
#  expires_on      :date
#  lock_version    :integer          default(0), not null
#  next_action     :text
#  notes           :text
#  scope_details   :text             not null
#  status          :string           default("draft"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  event_plan_id   :uuid             not null
#  user_id         :uuid             not null
#  vendor_id       :uuid             not null
#
# Indexes
#
#  index_vendor_quotes_on_event_plan_id               (event_plan_id)
#  index_vendor_quotes_on_plan_status_and_expiration  (event_plan_id,status,expires_on)
#  index_vendor_quotes_on_user_id                     (user_id)
#  index_vendor_quotes_on_user_id_and_created_at      (user_id,created_at)
#  index_vendor_quotes_on_vendor_id                   (vendor_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#  fk_rails_...  (vendor_id => vendors.id)
#
RSpec.describe VendorQuote, type: :model do
  it "normalizes and encrypts private quote details" do
    quote = create(
      :vendor_quote,
      currency: " usd ",
      scope_details: "  Dinner service\nfor twelve guests  ",
      next_action: "  Confirm the deposit  ",
      notes: "  Ask whether gratuity is included.  "
    )
    stored = described_class.connection.select_one(
      "SELECT scope_details, next_action, notes FROM vendor_quotes WHERE id = #{described_class.connection.quote(quote.id)}"
    )

    expect(quote).to have_attributes(
      currency: "USD",
      scope_details: "Dinner service\nfor twelve guests",
      next_action: "Confirm the deposit",
      notes: "Ask whether gratuity is included."
    )
    expect(stored.values).not_to include(quote.scope_details, quote.next_action, quote.notes)
  end

  it "parses a decimal amount without floating-point loss" do
    quote = build(:vendor_quote, amount: "1234.56")

    expect(quote).to be_valid
    expect(quote.amount_cents).to eq(123_456)
    expect(quote.amount).to eq("1234.56")

    quote.amount = "not money"
    expect(quote).not_to be_valid
    expect(quote.errors.of_kind?(:amount, :not_a_number)).to be(true)

    quote.amount = "1.234"
    expect(quote).not_to be_valid
    expect(quote.errors.of_kind?(:amount, :invalid_scale)).to be(true)
    expect(quote.amount_cents).to be_nil
    expect(quote.errors.full_messages).to include("Quote amount must use no more than two decimal places")
    I18n.with_locale(:es) do
      expect(quote.errors.full_messages).to include("Monto de la cotización debe usar como máximo dos decimales")
    end

    I18n.with_locale(:es) { quote.amount = "1.250,50" }
    expect(quote).to be_valid
    expect(quote.amount_cents).to eq(125_050)

    I18n.with_locale(:es) { quote.amount = "1.250" }
    expect(quote).to be_valid
    expect(quote.amount_cents).to eq(125_000)

    I18n.with_locale(:en) { quote.amount = "1,250.50" }
    expect(quote).to be_valid
    expect(quote.amount_cents).to eq(125_050)
  end

  it "requires bounded quote fields and a supported manual status" do
    quote = build(
      :vendor_quote,
      amount: nil,
      currency: "US dollars",
      scope_details: " ",
      status: "booked",
      expires_on: Date.new(2026, 9, 10),
      decision_due_on: Date.new(2026, 9, 11)
    )

    expect(quote).not_to be_valid
    expect(quote.errors.of_kind?(:amount, :blank)).to be(true)
    expect(quote.errors.of_kind?(:currency, :invalid)).to be(true)
    expect(quote.errors.of_kind?(:scope_details, :blank)).to be(true)
    expect(quote.errors.of_kind?(:status, :inclusion)).to be(true)
    expect(quote.errors.of_kind?(:decision_due_on, :after_expiration)).to be(true)
  end

  it "rejects a vendor or plan outside the owner boundary" do
    owner = create(:user)
    plan = create(:event_plan, user: owner, relationship_profile: create(:relationship_profile, user: owner))
    foreign_vendor = create(:vendor)
    quote = build(:vendor_quote, user: owner, event_plan: plan, vendor: foreign_vendor)

    expect(quote).not_to be_valid
    expect(quote.errors.of_kind?(:vendor, :different_owner)).to be(true)

    quote.vendor = create(:vendor, user: owner)
    quote.event_plan = create(:event_plan)
    expect(quote).not_to be_valid
    expect(quote.errors.of_kind?(:event_plan, :different_owner)).to be(true)
  end

  it "derives an expired display state and chooses the earliest reminder deadline" do
    Timecop.freeze(Time.zone.local(2026, 9, 17, 10)) do
      quote = build(
        :vendor_quote,
        status: "received",
        decision_due_on: Date.new(2026, 9, 19),
        expires_on: Date.new(2026, 9, 18)
      )

      expect(quote.display_status).to eq("received")
      expect(quote.next_deadline_on).to eq(Date.new(2026, 9, 18))

      Timecop.travel(Time.zone.local(2026, 9, 19, 10))
      expect(quote.display_status).to eq("expired")
      expect(quote.next_deadline_on).to eq(Date.new(2026, 9, 19))

      quote.decision_due_on = Date.new(2026, 9, 18)
      quote.expires_on = Date.new(2026, 9, 20)
      expect(quote.next_deadline_on).to eq(Date.new(2026, 9, 20))

      Timecop.travel(Time.zone.local(2026, 9, 21, 10))
      expect(quote.next_deadline_on).to be_nil
    end
  end

  it "keeps existing quote history but prevents new quotes for terminal plans" do
    quote = create(:vendor_quote)
    quote.event_plan.complete!

    expect(quote.reload).to be_valid
    expect(quote).not_to be_mutable
    expect(build(:vendor_quote, user: quote.user, vendor: quote.vendor, event_plan: quote.event_plan)).not_to be_valid
  end
end
