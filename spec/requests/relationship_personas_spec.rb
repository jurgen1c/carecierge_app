require "rails_helper"

RSpec.describe "Relationship personas", type: :request do
  it "renders an evidence-backed persona in the established relationship-profile list style" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    create(
      :relationship_preference,
      relationship_profile: profile,
      key: "Gift style",
      value: "Practical gifts",
      confidence: "confirmed",
      source_notes: "Maya asked for something useful."
    )
    create(
      :memory_record,
      relationship_profile: profile,
      title: "Quiet birthday plans",
      body: "Smaller birthday dinners were well received.",
      source: "ai_inferred",
      confidence: "medium"
    )
    sign_in user

    get relationship_profile_path(profile)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Relationship persona")
    expect(response.body).to include("A working picture of what matters to Maya")
    expect(response.body).to include("Gift style and Seems to suggest: Quiet birthday plans")
    expect(response.body).to include("Maya asked for something useful.")
    expect(response.body).to include("Smaller birthday dinners were well received.")
    expect(response.body).to include("Confirmed")
    expect(response.body).to include("Inferred")
    expect(response.body).to include("Correct trait")
  end

  it "renders a useful empty state" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    sign_in user

    get relationship_profile_path(profile)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No persona traits yet")
    expect(response.body).to include("Add reviewed memories or structured preferences")
  end

  it "localizes persona language in Spanish" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:relationship_preference, relationship_profile: profile, key: "Estilo de reunión", value: "Planes anticipados", confidence: "inferred")
    sign_in user

    I18n.with_locale(:es) do
      get relationship_profile_path(profile)
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Perfil de la relación")
    expect(response.body).to include("Parece sugerir: Estilo de reunión")
    expect(response.body).to include("Corregir rasgo")
    expect(response.body).not_to include("Translation missing")
  end

  it "refreshes the persona after a Turbo memory correction" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    memory = create(:memory_record, relationship_profile: profile, title: "Quiet birthday plans", body: "Original evidence")
    sign_in user

    patch relationship_profile_memory_record_path(profile, memory),
      params: { memory_record: { title: "Small birthday plans", body: "Corrected evidence", correction_note: "Clarified by the user." } },
      as: :turbo_stream

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(turbo-stream action="replace" target="relationship_persona_section"))
    expect(response.body).to include("Small birthday plans")
    expect(response.body).to include("Corrected evidence")
  end

  it "does not expose another user's persona" do
    sign_in create(:user)
    profile = create(:relationship_profile)
    create(:memory_record, relationship_profile: profile, title: "Private trait")

    get relationship_profile_path(profile)

    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include("Private trait")
  end
end
