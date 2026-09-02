require "rails_helper"

RSpec.describe "Vendors", type: :request do
  it "renders a searchable owner-scoped catalog with optional plan context" do
    user = create(:user)
    plan = create(:event_plan, user:, title: "Birthday dinner for Maya", budget_cents: 50_000)
    owned = create(:vendor, user:, name: "Bloom & Stem")
    create(:vendor, name: "Foreign vendor")
    sign_in user

    get vendors_path, params: { event_plan_id: plan.id, vendor_search: { category: owned.category } }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Find a vendor", "Birthday dinner for Maya", "Bloom &amp; Stem")
    expect(response.body).not_to include("Foreign vendor")
    expect(response.body).to include("Carecierge does not contact or book vendors")
    expect(response.body).to include(new_vendor_path(event_plan_id: plan.id))
  end

  it "makes the clear link explicitly remove event-plan search defaults" do
    plan = create(:event_plan, occasion_type: "birthday", budget_cents: 50_000)
    sign_in plan.user

    get vendors_path, params: { event_plan_id: plan.id }

    document = Nokogiri::HTML5(response.body)
    clear_link = document.css("a").find { |link| link.text.strip == "Clear filters" }
    query = Rack::Utils.parse_nested_query(URI.parse(clear_link["href"]).query)
    expect(query).to include("event_plan_id" => plan.id)
    expect(query.fetch("vendor_search")).to include("occasion_type" => "", "maximum_budget" => "")
  end

  it "renders the catalog in Spanish" do
    user = create(:user)
    create(:vendor, user:, name: "Flores del Valle")
    sign_in user

    I18n.with_locale(:es) { get vendors_path }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Buscar un proveedor", "Flores del Valle")
    expect(response.body).not_to include("Translation missing")
  end

  it "renders localized occasion choices in the Spanish vendor form" do
    vendor = create(:vendor, occasion_types: [ "birthday" ])
    sign_in vendor.user

    I18n.with_locale(:es) { get edit_vendor_path(vendor) }

    document = Nokogiri::HTML5(response.body)
    occasion_fieldset = document.at_css("fieldset[data-vendor-occasions]")
    expect(occasion_fieldset.text).to include("Cumpleaños", "Cita")
    expect(occasion_fieldset.text).not_to include("birthday", "date_night")
    expect(occasion_fieldset.at_css("input[value='birthday']")["checked"]).to eq("checked")
  end

  it "creates a manual saved vendor and attaches it to an owned active plan" do
    user = create(:user)
    plan = create(:event_plan, user:)
    sign_in user

    expect do
      post vendors_path, params: {
        event_plan_id: plan.id,
        vendor: {
          name: "  Casa Verde  ",
          category: "restaurant",
          location: "San Jose",
          minimum_price: "40",
          maximum_price: "75",
          availability: "Friday evenings",
          occasion_types_text: "birthday, anniversary",
          preference_tags_text: "quiet, vegetarian",
          fit_notes: "A calm room with vegetarian options.",
          source_kind: "external",
          source_name: "Vendor website",
          source_url: "https://example.com/casa-verde"
        }
      }
    end.to change(user.vendors, :count).by(1).and change(EventPlanVendor, :count).by(1)

    vendor = user.vendors.reload.sole
    expect(vendor).to have_attributes(
      name: "Casa Verde",
      category: "restaurant",
      minimum_price_cents: 4_000,
      maximum_price_cents: 7_500,
      occasion_types: %w[birthday anniversary],
      preference_tags: %w[quiet vegetarian]
    )
    expect(vendor.event_plans).to contain_exactly(plan)
    expect(response).to redirect_to(vendors_path(event_plan_id: plan.id))
  end

  it "requires plan update authorization when creation would attach a vendor" do
    user = create(:user)
    plan = create(:event_plan, user:)
    sign_in user
    allow_any_instance_of(EventPlanPolicy).to receive(:show?).and_return(true)
    allow_any_instance_of(EventPlanPolicy).to receive(:update?).and_return(false)

    expect do
      post vendors_path, params: {
        event_plan_id: plan.id,
        vendor: { name: "Casa Verde", category: "restaurant", source_kind: "manual" }
      }
    end.not_to change(Vendor, :count)

    expect(response).to have_http_status(:forbidden)
  end

  it "does not expose or attach vendors and plans across owners" do
    user = create(:user)
    foreign_vendor = create(:vendor)
    foreign_plan = create(:event_plan)
    sign_in user

    get edit_vendor_path(foreign_vendor)
    expect(response).to have_http_status(:not_found)

    expect do
      post event_plan_vendors_path(foreign_plan), params: { vendor_id: foreign_vendor.id }
    end.not_to change(EventPlanVendor, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "attaches and removes an owned vendor without external side effects" do
    vendor = create(:vendor)
    plan = create(:event_plan, user: vendor.user)
    sign_in vendor.user

    expect do
      post event_plan_vendors_path(plan), params: { vendor_id: vendor.id }
    end.to change(EventPlanVendor, :count).by(1)

    assignment = EventPlanVendor.sole
    expect do
      delete event_plan_vendor_path(plan, assignment)
    end.to change(EventPlanVendor, :count).by(-1)
  end

  it "rejects invalid vendor input and keeps the no-JavaScript form usable" do
    user = create(:user)
    sign_in user

    expect do
      post vendors_path, params: { vendor: { name: "", category: "unknown", source_kind: "external" } }
    end.not_to change(Vendor, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Add a vendor", "Vendor name can&#39;t be blank")
  end

  it "renders Spanish validation messages with localized vendor attributes" do
    user = create(:user)
    sign_in user

    I18n.with_locale(:es) do
      post vendors_path, params: { vendor: { name: "", category: "unknown", source_kind: "external" } }
    end

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(
      "Nombre del proveedor no puede estar en blanco",
      "Categoría no está incluido en la lista",
      "Nombre de la fuente no puede estar en blanco"
    )
    expect(response.body).not_to include("Name no puede", "Category no está", "Source name no puede")
  end

  it "keeps update and delete in separate semantic forms" do
    vendor = create(:vendor)
    sign_in vendor.user

    get edit_vendor_path(vendor)

    document = Nokogiri::HTML5(response.body)
    forms = document.css("form[action='#{vendor_path(vendor)}']")
    expect(forms.length).to eq(2)
    expect(forms.map { |form| form.css("input[name='_method']").map { |input| input["value"] } }).to contain_exactly(
      [ "patch" ],
      [ "delete" ]
    )
  end

  it "preserves a vendor and its private notes while it belongs to a comparison" do
    option = create(:vendor_option, notes: "Keep this comparison context")
    vendor = option.vendor
    sign_in vendor.user

    expect do
      delete vendor_path(vendor)
    end.not_to change(Vendor, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Remove this vendor from every comparison before deleting it")
    expect(option.reload.notes).to eq("Keep this comparison context")
  end

  it "does not open mutable vendor context for a completed plan" do
    plan = create(:event_plan, status: "completed", completed_at: Time.current)
    sign_in plan.user

    get vendors_path, params: { event_plan_id: plan.id }

    expect(response).to have_http_status(:not_found)
  end
end
