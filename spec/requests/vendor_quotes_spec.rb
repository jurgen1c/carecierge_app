require "rails_helper"

RSpec.describe "Vendor quotes", type: :request do
  it "renders a private plan comparison with manual-only actions" do
    quote = create(:vendor_quote)
    sign_in quote.user

    get event_plan_vendor_quotes_path(quote.event_plan)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css("meta[name='turbo-cache-control']")&.[]("content")).to eq("no-cache")
    expect(response.parsed_body.text).to include("Vendor quotes", quote.event_plan.title, quote.vendor.name, "$1,250.00 USD")
    expect(response.body).to include("Add quote", "Set reminder", "Review quote")
    expect(response.body).not_to include("Contact vendor", "Book vendor", "Pay deposit", "Purchase")
  end

  it "teaches the first manual action when a plan has no quotes" do
    plan = create(:event_plan)
    sign_in plan.user

    get event_plan_vendor_quotes_path(plan)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No quotes yet", "Add the first quote")
    expect(response.body).to include(new_event_plan_vendor_quote_path(plan))
  end

  it "provides an owner-scoped history entry point for archived-plan quotes" do
    quote = create(:vendor_quote, notes: "Private loading-access details")
    foreign_quote = create(:vendor_quote)
    create_list(:vendor_quote, 20, user: quote.user, event_plan: quote.event_plan, vendor: quote.vendor)
    quote.event_plan.archive!
    sign_in quote.user

    get vendor_quotes_path

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.text).to include("Quote history", quote.event_plan.title, quote.vendor.name)
    expect(response.body).to include(event_plan_vendor_quotes_path(quote.event_plan))
    expect(response.body).not_to include(foreign_quote.event_plan.title, foreign_quote.vendor.name)
    expect(response.body).to include("Page 1 of 2")

    get event_plan_vendor_quotes_path(quote.event_plan)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Private loading-access details")
    back_link = response.parsed_body.css("a").find { |link| link.text.include?("Back to quote history") }
    expect(back_link&.[]("href")).to eq(vendor_quotes_path)
  end

  it "creates and updates an owner-scoped quote" do
    plan = create(:event_plan)
    vendor = create(:vendor, user: plan.user)
    sign_in plan.user

    expect do
      post event_plan_vendor_quotes_path(plan), params: {
        vendor_quote: {
          vendor_id: vendor.id,
          amount: "975.50",
          currency: "crc",
          scope_details: "Private dining room and dinner",
          expires_on: "2026-09-20",
          decision_due_on: "2026-09-18",
          status: "received",
          next_action: "Confirm accessibility",
          notes: "Taxes included"
        }
      }
    end.to change(VendorQuote, :count).by(1)

    quote = VendorQuote.last
    expect(quote).to have_attributes(
      user: plan.user,
      event_plan: plan,
      vendor:,
      amount_cents: 97_550,
      currency: "CRC",
      next_action: "Confirm accessibility"
    )
    expect(response).to redirect_to(event_plan_vendor_quotes_path(plan))

    patch vendor_quote_path(quote), params: {
      vendor_quote: {
        amount: "1000.00",
        currency: "CRC",
        scope_details: quote.scope_details,
        status: "under_review",
        lock_version: quote.lock_version
      }
    }

    expect(response).to redirect_to(event_plan_vendor_quotes_path(plan))
    expect(quote.reload).to have_attributes(amount_cents: 100_000, status: "under_review")
  end

  it "rejects foreign plan and vendor identifiers without leaking records" do
    owner = create(:user)
    owned_plan = create(:event_plan, user: owner, relationship_profile: create(:relationship_profile, user: owner))
    foreign_plan = create(:event_plan)
    foreign_vendor = create(:vendor)
    sign_in owner

    get event_plan_vendor_quotes_path(foreign_plan)
    expect(response).to have_http_status(:not_found)

    expect do
      post event_plan_vendor_quotes_path(owned_plan), params: {
        vendor_quote: attributes_for(:vendor_quote).merge(vendor_id: foreign_vendor.id)
      }
    end.not_to change(VendorQuote, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "ignores forged vendor changes on quote updates without disclosing another owner's vendor" do
    quote = create(:vendor_quote)
    original_vendor = quote.vendor
    foreign_vendor = create(:vendor, name: "Private foreign vendor")
    sign_in quote.user

    patch vendor_quote_path(quote), params: {
      vendor_quote: {
        vendor_id: foreign_vendor.id,
        amount: quote.amount,
        currency: quote.currency,
        scope_details: quote.scope_details,
        status: quote.status,
        lock_version: quote.lock_version
      }
    }

    expect(response).to redirect_to(event_plan_vendor_quotes_path(quote.event_plan))
    expect(response.body).not_to include(foreign_vendor.name)
    expect(quote.reload.vendor).to eq(original_vendor)
  end

  it "computes the owner-local comparison date once for every quote" do
    quote = create(:vendor_quote)
    create(:vendor_quote, user: quote.user, event_plan: quote.event_plan, vendor: create(:vendor, user: quote.user))
    sign_in quote.user
    allow(OwnerLocalCalendar).to receive(:date_for).and_return(Date.new(2026, 9, 3))

    get event_plan_vendor_quotes_path(quote.event_plan)

    expect(OwnerLocalCalendar).to have_received(:date_for).once.with(user: quote.user)
  end

  it "rejects stale and unversioned updates without overwriting private quote details" do
    quote = create(:vendor_quote, notes: "Original")
    rendered_version = quote.lock_version
    quote.update!(notes: "Newer private note")
    sign_in quote.user

    patch vendor_quote_path(quote), params: {
      vendor_quote: {
        amount: quote.amount,
        currency: quote.currency,
        scope_details: quote.scope_details,
        status: quote.status,
        notes: "Stale overwrite",
        lock_version: rendered_version
      }
    }

    expect(response).to redirect_to(event_plan_vendor_quotes_path(quote.event_plan))
    expect(flash[:alert]).to eq("The quote changed before your update was saved. Review it and try again.")
    expect(quote.reload.notes).to eq("Newer private note")

    patch vendor_quote_path(quote), params: { vendor_quote: { notes: "Unversioned overwrite" } }
    expect(response).to have_http_status(:bad_request)
    expect(quote.reload.notes).to eq("Newer private note")
  end

  it "keeps terminal-plan quotes read-only while allowing explicit deletion" do
    quote = create(:vendor_quote)
    quote.event_plan.complete!
    sign_in quote.user

    get event_plan_vendor_quotes_path(quote.event_plan)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Quote details are read-only")
    expect(response.body).not_to include("Add quote", "Review quote", "Set reminder")

    expect do
      delete vendor_quote_path(quote)
    end.to change(VendorQuote, :count).by(-1)
    expect(response).to redirect_to(event_plan_vendor_quotes_path(quote.event_plan))
  end

  it "renders the workflow in Spanish" do
    quote = create(:vendor_quote)
    sign_in quote.user

    I18n.with_locale(:es) { get event_plan_vendor_quotes_path(quote.event_plan) }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Cotizaciones de proveedores", "Agregar cotización", "Configurar recordatorio")
    expect(response.body).not_to include("Translation missing")
  end
end
