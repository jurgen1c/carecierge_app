require "rails_helper"

RSpec.describe "Gift boxes", type: :request do
  let(:profile) { create(:relationship_profile) }
  let(:path) { relationship_profile_gift_boxes_path(profile) }
  let(:attributes) do
    { name: "Reading box", occasion: "Birthday", budget: "40.25", currency: "USD", notes: "Private recipient logistics", constraints: "No food", delivery_on: "2026-10-04",
      items_attributes: { "0" => { name: "Book", cost: "20.25", vendor: "Local shop", purchase_url: "https://books.example/item", purchased: "1", completed: "0" } } }
  end
  before { sign_in profile.user }

  it "creates and edits a private box with independently tracked items and an exact budget" do
    expect { post path, params: { gift_box: attributes } }.to change { profile.gift_boxes.count }.by(1)
    box = profile.gift_boxes.last
    expect(box).to have_attributes(occasion: "Birthday", budget: BigDecimal("40.25"))
    expect(box.items.sole).to have_attributes(purchased: true, completed: false, vendor: "Local shop")
    get relationship_profile_gift_box_path(profile, box)
    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.body).to include("Private recipient logistics", "Local shop", "20.25")
    expect(response.parsed_body.at_css("a[href='https://books.example/item']")["rel"]).to include("noreferrer")
    patch relationship_profile_gift_box_path(profile, box), params: { gift_box: { lock_version: box.lock_version, items_attributes: { "0" => { id: box.items.sole.id, completed: "1" } } } }
    expect(box.items.reload.sole).to be_completed
    expect(box.items.sole).to be_purchased
  end

  it "rejects foreign relationships, nested item injection, stale updates and archived profiles" do
    post path, params: { gift_box: attributes }
    box = profile.gift_boxes.last
    other = create(:relationship_profile)
    get relationship_profile_gift_boxes_path(other)
    expect(response).to have_http_status(:not_found)
    patch relationship_profile_gift_box_path(profile, box), params: { gift_box: { lock_version: box.lock_version, items_attributes: { "0" => { id: SecureRandom.uuid, name: "Injected" } } } }
    expect(response).to have_http_status(:not_found)
    patch relationship_profile_gift_box_path(profile, box), params: { gift_box: { lock_version: "99", notes: "Stale" } }
    expect(box.reload.notes).to eq("Private recipient logistics")
    profile.discard!
    get path
    expect(response).to have_http_status(:not_found)
  end

  it "retains invalid inputs and renders both locales" do
    post path, params: { gift_box: attributes.merge(budget: "1.999") }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Private recipient logistics")
    expect(profile.gift_boxes).to be_empty
    I18n.with_locale(:es) { get path }
    expect(response.body).to include("Cajas de regalo")
    expect(response.body).not_to include("Translation missing")
  end

  it "prefills a delivery reminder for review without creating it or leaking notes" do
    post path, params: { gift_box: attributes }
    box = profile.gift_boxes.last
    create(:notification_preference, user: profile.user, time_zone: "America/Costa_Rica", time_zone_configured: true)
    expect { get new_reminder_path(gift_box_id: box.id) }.not_to change(Reminder, :count)
    expect(response.parsed_body.at_css("input[name='reminder[scheduled_at]']")["value"]).to eq("2026-10-04T09:00")
    expect(response.body).not_to include("Private recipient logistics")
    sign_in create(:user)
    get new_reminder_path(gift_box_id: box.id)
    expect(response).to have_http_status(:not_found)
  end
  it "keeps older boxes reachable through pagination" do
    21.times { |index| profile.gift_boxes.create!(name: "Box #{index}", occasion: "Birthday") }
    get path
    expect(response.parsed_body.at_css("a[rel='next']")).to be_present
    get path, params: { page: 2 }
    expect(response.body).to include("Box 0")
  end

  it "localizes invalid Spanish amounts including nested item errors" do
    invalid = attributes.deep_dup
    invalid[:budget] = "bad"
    invalid[:items_attributes]["0"][:cost] = "bad"
    invalid[:items_attributes]["0"][:purchase_url] = "javascript:bad"
    I18n.with_locale(:es) { post path, params: { gift_box: invalid } }
    expect(response).to have_http_status(:unprocessable_content)
    errors = response.parsed_body.at_css("[role='alert']").text
    expect(errors).to include("Presupuesto", "Costo", "Enlace")
    expect(errors).not_to match(/\bBudget\b|\bCost\b|Purchase url/)
  end
end
