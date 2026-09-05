require "rails_helper"

RSpec.describe "External provider actions", type: :request do
  let(:profile) { create(:relationship_profile) }
  let(:attributes) do
    { provider_name: "Casa Verde", provider_kind: "reservation", action_kind: "booking",
      status: "pending", source_label: "Phone confirmation", source_url: "https://example.com/reservations",
      external_reference: "PRIVATE-123", failure_details: nil }
  end

  before { sign_in profile.user }

  it "records manual provider state, audits without content and renders the owner ledger" do
    expect do
      post relationship_profile_external_provider_actions_path(profile), params: { external_provider_action: attributes }
    end.to change { profile.external_provider_actions.count }.by(1).and change(AuditEvent, :count).by(1)
    record = profile.external_provider_actions.sole
    expect(record).to have_attributes(user: profile.user, status: "pending")
    expect(record.read_attribute_before_type_cast(:external_reference)).not_to include("PRIVATE-123")
    expect(AuditEvent.last.metadata.to_json).not_to include("Casa Verde", "PRIVATE-123")
    get relationship_profile_external_provider_actions_path(profile)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Casa Verde", "Phone confirmation", "Manual records", "PRIVATE-123")
  end

  it "rejects foreign links and never changes another owner's state" do
    foreign = create(:booking)
    post relationship_profile_external_provider_actions_path(profile), params: {
      external_provider_action: attributes.merge(booking_id: foreign.id)
    }
    expect(response).to have_http_status(:not_found)
    expect(ExternalProviderAction.count).to eq(0)
  end

  it "rejects unsafe links and requires failure details for failed state" do
    post relationship_profile_external_provider_actions_path(profile), params: {
      external_provider_action: attributes.merge(source_url: "javascript:alert(1)", status: "failed")
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(ExternalProviderAction.count).to eq(0)
  end

  it "keeps versioned edits manual and audits deletion" do
    post relationship_profile_external_provider_actions_path(profile), params: { external_provider_action: attributes }
    record = profile.external_provider_actions.sole
    patch external_provider_action_path(record), params: { external_provider_action: { status: "confirmed", lock_version: record.lock_version } }
    expect(record.reload.status).to eq("confirmed")
    patch external_provider_action_path(record), params: { external_provider_action: { status: "cancelled", lock_version: 0 } }
    expect(record.reload.status).to eq("confirmed")
    expect(response).to have_http_status(:redirect)
    expect { delete external_provider_action_path(record) }.to change(ExternalProviderAction, :count).by(-1).and change(AuditEvent, :count).by(1)
  end

  it "denies foreign reads and mutations and supports Spanish forms" do
    get relationship_profile_external_provider_actions_path(create(:relationship_profile))
    expect(response).to have_http_status(:not_found)
    I18n.with_locale(:es) { get new_relationship_profile_external_provider_action_path(profile) }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Proveedor", "Registros manuales")
  end
  it "renders every typed context and the owner's local observation time" do
    create(:notification_preference, user: profile.user, time_zone: "America/Costa_Rica", time_zone_configured: true)
    plan = create(:event_plan, user: profile.user, relationship_profile: profile)
    gift = create(:gift, relationship_profile: profile)
    purchase = GiftPurchasePlan.create!(gift:, options: [])
    booking = create(:booking, user: profile.user, event_plan: plan)
    quote = create(:vendor_quote, user: profile.user, event_plan: plan)
    reminder = create(:reminder, user: profile.user, relationship_profile: profile, event_plan: plan)
    Timecop.freeze(Time.utc(2026, 9, 5, 13)) do
      post relationship_profile_external_provider_actions_path(profile), params: {
        external_provider_action: attributes.merge(event_plan_id: plan.id, gift_purchase_plan_id: purchase.id,
          booking_id: booking.id, vendor_quote_id: quote.id, reminder_id: reminder.id)
      }
    end
    get relationship_profile_external_provider_actions_path(profile)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("07:00", "Gift purchase plan:", "Event plan:", "Booking:", "Quote:", "Reminder:")
    get edit_external_provider_action_path(profile.external_provider_actions.sole)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(purchase.id, booking.id, quote.id, reminder.id)
  end
end
