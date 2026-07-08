# == Schema Information
#
# Table name: gifts
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  given_on                :date
#  name                    :string           not null
#  notes                   :text
#  occasion                :string
#  outcome                 :string
#  price_cents             :integer
#  reaction                :text
#  status                  :string           default("idea"), not null
#  vendor                  :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_gifts_on_relationship_profile_id               (relationship_profile_id)
#  index_gifts_on_relationship_profile_id_and_given_on  (relationship_profile_id,given_on)
#  index_gifts_on_relationship_profile_id_and_outcome   (relationship_profile_id,outcome)
#  index_gifts_on_relationship_profile_id_and_status    (relationship_profile_id,status)
#  index_gifts_on_profile_and_lower_name                (relationship_profile_id, lower((name)::text))
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
require "rails_helper"

RSpec.describe Gift, type: :model do
  describe "relationship profile gift lists" do
    it "separates active ideas from given gift history" do
      profile = create(:relationship_profile)
      idea = create(:gift, relationship_profile: profile, status: "idea", name: "Ceramic mug")
      planned = create(:gift, relationship_profile: profile, status: "planned", name: "Coffee beans")
      given = create(:gift, relationship_profile: profile, status: "given", name: "Concert tickets", given_on: Date.new(2026, 7, 7))

      profile.reload
      expect(profile.gift_ideas).to contain_exactly(idea, planned)
      expect(profile.gift_history).to contain_exactly(given)
    end

    it "orders gift history by newest given date while keeping names ascending for date ties" do
      profile = create(:relationship_profile)
      older = create(:gift, relationship_profile: profile, status: "given", name: "Notebook", given_on: Date.new(2026, 6, 1))
      same_date_b = create(:gift, relationship_profile: profile, status: "given", name: "Zoo pass", given_on: Date.new(2026, 7, 7))
      same_date_a = create(:gift, relationship_profile: profile, status: "given", name: "Art print", given_on: Date.new(2026, 7, 7))
      newer = create(:gift, relationship_profile: profile, status: "given", name: "Coffee class", given_on: Date.new(2026, 8, 1))

      expect(profile.reload.gift_history).to eq([ newer, same_date_a, same_date_b, older ])
    end
  end

  describe "#duplicate_candidate?" do
    it "detects prior gifts with the same normalized name for the same relationship profile" do
      profile = create(:relationship_profile)
      create(:gift, relationship_profile: profile, name: "  Noise-canceling headphones ", status: "given")

      gift = build(:gift, relationship_profile: profile, name: "noise-canceling HEADPHONES")

      expect(gift).to be_duplicate_candidate
    end

    it "does not treat another relationship profile's gift as a duplicate" do
      create(:gift, name: "Noise-canceling headphones", status: "given")
      gift = build(:gift, name: "Noise-canceling headphones")

      expect(gift).not_to be_duplicate_candidate
    end

    it "uses the loaded relationship gift collection when available" do
      profile = create(:relationship_profile)
      create(:gift, relationship_profile: profile, name: "Noise-canceling headphones", status: "given")
      gift = create(:gift, relationship_profile: profile, name: "noise-canceling HEADPHONES")
      profile.reload
      profile.gifts.load

      expect(profile.gifts).to be_loaded
      expect(gift).to be_duplicate_candidate
    end

    it "uses the loaded relationship gift collection for unsaved gifts" do
      profile = create(:relationship_profile)
      create(:gift, relationship_profile: profile, name: "Noise-canceling headphones", status: "given")
      gifts = profile.reload.gifts.load
      gift = build(:gift, relationship_profile: profile, name: "noise-canceling HEADPHONES")

      expect(gifts).not_to receive(:where)
      expect(gift).to be_duplicate_candidate
    end

    it "uses cached loaded gift names instead of scanning the collection for each check" do
      profile = create(:relationship_profile)
      create(:gift, relationship_profile: profile, name: "Noise-canceling headphones", status: "given")
      create(:gift, relationship_profile: profile, name: "noise-canceling HEADPHONES", status: "planned")
      gifts = profile.reload.gifts.load
      gift = gifts.second
      gift.relationship_profile = profile

      expect(gifts).not_to receive(:any?)
      expect(gifts).not_to receive(:where)
      expect(gift).to be_duplicate_candidate
    end
  end

  describe ".editable_status_options" do
    it "keeps terminal given status out of the generic edit form" do
      option_values = described_class.editable_status_options.map(&:second)

      expect(option_values).to eq(%w[idea planned])
      expect(option_values).not_to include("given", "archived")
    end
  end

  describe "#price=" do
    it "formats cents without floating-point conversion" do
      gift = build(:gift, price_cents: 8999)

      expect(gift.price).to eq("89.99")
      expect(gift.price_amount).to eq(BigDecimal("89.99"))
    end

    it "treats non-finite values as validation errors" do
      gift = build(:gift, price: "NaN")

      expect(gift).not_to be_valid
      expect(gift.errors[:price]).to include("is not a number")
    end

    it "treats prices beyond the integer cents column range as validation errors" do
      gift = build(:gift, price: "999999999999999999.99")

      expect(gift).not_to be_valid
      expect(gift.errors[:price]).to include("must be less than or equal to 21474836.47")
    end
  end

  describe "localized validation labels" do
    it "labels price_cents errors like the visible price field" do
      gift = build(:gift, price_cents: -1)

      expect(gift).not_to be_valid

      I18n.with_locale(:en) do
        expect(gift.errors.full_messages).to include("Price must be greater than or equal to 0")
      end

      I18n.with_locale(:es) do
        expect(gift.errors.full_messages).to include("Precio debe ser mayor que o igual a 0")
      end
    end
  end

  describe "#mark_given!" do
    it "marks the gift given with reaction and outcome metadata" do
      gift = create(:gift, status: "planned")

      gift.mark_given!(
        given_on: Date.new(2026, 7, 7),
        reaction: "She uses it every morning.",
        outcome: "successful"
      )

      expect(gift).to be_given
      expect(gift).to have_attributes(
        given_on: Date.new(2026, 7, 7),
        reaction: "She uses it every morning.",
        outcome: "successful"
      )
    end
  end
end
