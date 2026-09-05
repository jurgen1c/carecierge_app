require "rails_helper"

RSpec.describe ExternalProviderAction, type: :model do
  let(:profile) { create(:relationship_profile) }
  let(:record) do
    described_class.new(user: profile.user, relationship_profile: profile, provider_name: "Private provider",
      provider_kind: "commerce", action_kind: "purchase", status: "pending", source_label: "Email from provider", recorded_at: Time.utc(2026, 9, 5))
  end

  it "represents all four provider categories and rejects unsupported kinds" do
    described_class::PROVIDER_KINDS.each { |kind| expect(record.tap { |r| r.provider_kind = kind }).to be_valid }
    record.provider_kind = "automatic_checkout"
    expect(record).not_to be_valid
  end

  it "connects every supported context without changing its status" do
    plan = create(:event_plan, user: profile.user, relationship_profile: profile)
    gift = create(:gift, relationship_profile: profile)
    purchase = GiftPurchasePlan.create!(gift:, options: [])
    booking = create(:booking, user: profile.user, event_plan: plan)
    quote = create(:vendor_quote, user: profile.user, event_plan: plan)
    reminder = create(:reminder, user: profile.user, relationship_profile: profile, event_plan: plan)
    record.assign_attributes(gift_purchase_plan: purchase, event_plan: plan, booking:, vendor_quote: quote, reminder:)
    expect { ExternalProviderActions::Save.call(record, actor: profile.user, attributes: { status: "completed" }) }
      .not_to change { [ purchase.reload.purchase_status, booking.reload.status, quote.reload.status, reminder.reload.status ] }
    expect(record.reload).to be_persisted
    exported = DataExports::Snapshot.new(user: profile.user, relationship_profile: profile).to_h
    expect(exported["relationship_profiles"].sole["external_provider_actions"].sole).to include("provider_name" => "Private provider", "gift_purchase_plan_id" => purchase.id)
    expect { purchase.destroy! }.to change(described_class, :count).by(-1)
  end

  it "rejects another relationship even when owned by the same user" do
    other_profile = create(:relationship_profile, user: profile.user)
    record.event_plan = create(:event_plan, user: profile.user, relationship_profile: other_profile)
    expect(record).not_to be_valid
    expect(record.errors[:event_plan]).to be_present
  end

  it "rejects contradictory event links" do
    record.event_plan = create(:event_plan, user: profile.user, relationship_profile: profile)
    record.booking = create(:booking, user: profile.user, event_plan: create(:event_plan, user: profile.user, relationship_profile: profile))
    expect(record).not_to be_valid
  end

  it "includes the gift purchase plan's event in consistency checks" do
    first_plan = create(:event_plan, user: profile.user, relationship_profile: profile)
    gift = create(:gift, relationship_profile: profile)
    record.gift_purchase_plan = GiftPurchasePlan.create!(gift:, options: [], plan_task: create(:plan_task, event_plan: first_plan))
    record.event_plan = create(:event_plan, user: profile.user, relationship_profile: profile)
    expect(record).not_to be_valid
    expect(record.errors[:event_plan]).to be_present
    record.event_plan = first_plan
    expect(record).to be_valid
  end

  it "requires failure detail and clears stale failure information after recovery" do
    record.status = "failed"
    expect(record).not_to be_valid
    record.failure_details = "Delivery delayed; call tomorrow"
    expect(record).to be_valid
    record.save!
    expect(record.read_attribute_before_type_cast(:failure_details)).not_to include("Delivery delayed")
    record.update!(status: "confirmed")
    expect(record.failure_details).to be_nil
  end

  it "allows only http sources without embedded credentials" do
    [ "javascript:alert(1)", "https://user:password@example.com", "//example.com", "https://bad host" ].each do |url|
      record.source_url = url
      expect(record).not_to be_valid
    end
    record.source_url = "https://example.com/details"
    expect(record).to be_valid
  end

  it "rolls back local state when audit evidence cannot be recorded" do
    allow(AuditEvent).to receive(:record!).and_raise(ActiveRecord::RecordInvalid)
    expect do
      expect { ExternalProviderActions::Save.call(record, actor: profile.user, attributes: {}) }.to raise_error(ActiveRecord::RecordInvalid)
    end.not_to change(described_class, :count)
  end

  it "denies unauthorised service actors and archived profile edits but allows cleanup" do
    expect { ExternalProviderActions::Save.call(record, actor: create(:user), attributes: {}) }.to raise_error(Pundit::NotAuthorizedError)
    ExternalProviderActions::Save.call(record, actor: profile.user, attributes: {})
    profile.discard!
    expect { ExternalProviderActions::Save.call(record, actor: profile.user, attributes: {}, expected_lock_version: record.lock_version) }.to raise_error(ActiveRecord::RecordNotFound)
    expect { ExternalProviderActions::Destroy.call(record, actor: profile.user) }.to change(described_class, :count).by(-1)
  end

  it "records deterministic local observation time and cascades with the relationship" do
    Timecop.freeze(Time.utc(2026, 9, 5, 13)) do
      ExternalProviderActions::Save.call(record, actor: profile.user, attributes: {})
      expect(record.recorded_at).to eq(Time.current)
    end
    expect { profile.destroy! }.to change(described_class, :count).by(-1)
  end
end
