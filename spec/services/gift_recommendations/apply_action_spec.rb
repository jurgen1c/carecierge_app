require "rails_helper"

RSpec.describe GiftRecommendations::ApplyAction do
  it "dismisses a generated recommendation idempotently without creating a gift" do
    recommendation = create(:gift_recommendation)
    profile = recommendation.relationship_profile
    dismissed_at = Time.zone.parse("2026-08-19 10:00:00")

    expect do
      described_class.call(actor: recommendation.user, recommendation:, action: "dismiss", at: dismissed_at)
    end.not_to change(profile.gifts, :count)

    expect(recommendation.reload).to have_attributes(status: "dismissed", dismissed_at: dismissed_at)
    expect do
      described_class.call(actor: recommendation.user, recommendation:, action: "dismiss", at: dismissed_at + 1.hour)
    end.not_to change(AuditEvent, :count)
    expect(recommendation.reload.dismissed_at).to eq(dismissed_at)
  end

  it "rejects unsupported actions before changing state" do
    recommendation = create(:gift_recommendation)

    expect do
      described_class.call(actor: recommendation.user, recommendation:, action: "order")
    end.to raise_error(ArgumentError, "unsupported gift recommendation action")
    expect(recommendation.reload).to be_generated
  end

  it "rejects a different action after the recommendation leaves generated state" do
    recommendation = create(:gift_recommendation, status: "saved", saved_at: Time.current)

    expect do
      described_class.call(actor: recommendation.user, recommendation:, action: "purchase")
    end.to raise_error(ActiveRecord::RecordInvalid)
    expect(recommendation.reload).to be_saved
  end
end
