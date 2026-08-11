require "rails_helper"

RSpec.describe "Relationship memory search", type: :request do
  it "requires authentication" do
    get relationship_search_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "renders a private initial state without running a broad search" do
    user = create(:user)
    create(:relationship_profile, user:, first_name: "Ana")
    sign_in user

    get relationship_search_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("relationship_searches.show.heading"))
    expect(response.body).to include(I18n.t("relationship_searches.show.initial_title"))
    expect(response.body).to include(I18n.t("relationship_searches.show.vault_notice"))
    expect(response.body).to include(I18n.t("relationship_searches.source_types.preferences"))
    expect(response.body).not_to include("Translation missing")
    result_count = I18n.t(
      "relationship_searches.show.results_count",
      count: 1,
      relationships: I18n.t("relationship_searches.show.relationship_count", count: 1)
    )
    expect(response.body).not_to include(result_count)
  end

  it "ignores search filters submitted through a GET URL" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:gift, relationship_profile: profile, name: "Private hiking plan")
    sign_in user

    get relationship_search_path, params: { memory_query: "private hiking plan", source: "gifts" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("relationship_searches.show.initial_title"))
    expect(response.body).not_to include("Private hiking plan")
  end

  it "submits sensitive search text in a POST body instead of the URL" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:gift, relationship_profile: profile, name: "Private hiking plan")
    sign_in user

    get relationship_search_path

    fragment = Nokogiri::HTML5.fragment(response.body)
    search_form = fragment.at_css("form[action='#{relationship_search_path}']")
    expect(search_form["method"]).to eq("post")
    expect(search_form["data-turbo"]).to eq("false")

    post relationship_search_path, params: { memory_query: "private hiking plan", source: "gifts" }

    expect(response).to have_http_status(:ok)
    expect(response.request.fullpath).to eq(relationship_search_path)
    expect(response.body).to include("Private hiking plan")
  end

  it "keeps sensitive search text in POST bodies while paginating" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create_list(:gift, 21, relationship_profile: profile, name: "Private hiking plan")
    sign_in user

    post relationship_search_path, params: { memory_query: "private hiking plan", source: "gifts" }

    fragment = Nokogiri::HTML5.fragment(response.body)
    next_button = fragment.css("button").find do |button|
      button.text.include?(I18n.t("relationship_searches.show.pagination.next"))
    end
    pagination_form = next_button.ancestors("form").first

    expect(pagination_form["method"]).to eq("post")
    expect(pagination_form["action"]).to eq(relationship_search_path)
    expect(pagination_form.at_css("input[name='memory_query']")["value"]).to eq("private hiking plan")
  end

  it "renders an empty page for a stale pagination value" do
    sign_in create(:user)

    get relationship_search_path, params: { page: 2 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("relationship_searches.show.initial_title"))
  end

  it "resets an out-of-range result page to the first matching page" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:gift, relationship_profile: profile, name: "Hiking guide")
    sign_in user

    post relationship_search_path, params: { memory_query: "hiking", source: "gifts", page: 2 }

    expect(response.body).to include("Hiking guide")
    expect(response.body).not_to include(I18n.t("relationship_searches.show.empty_title"))
  end

  it "bounds oversized pagination values before Pagy slices search results" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:gift, relationship_profile: profile, name: "Hiking guide")
    sign_in user

    post relationship_search_path,
      params: { memory_query: "hiking", source: "gifts", page: "9" * 100 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Hiking guide")
  end

  it "resets an empty out-of-range page when the result count is an exact page multiple" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create_list(:gift, 20, relationship_profile: profile, name: "Hiking guide")
    sign_in user

    post relationship_search_path, params: { memory_query: "hiking", source: "gifts", page: 2 }

    expect(response.body).to include("Hiking guide")
    expect(response.body).not_to include(I18n.t("relationship_searches.show.empty_title"))
  end

  it "links derivative timeline matches to the editable source workflow" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    recap = create(:conversation_recap, relationship_profile: profile, title: "Conversation plan")
    create(
      :timeline_entry,
      relationship_profile: profile,
      source_record: recap,
      origin: "system",
      entry_type: "conversation_recap",
      title: recap.title
    )
    create(
      :interaction,
      :derived_from_conversation_recap,
      relationship_profile: profile,
      source: recap
    )
    sign_in user

    post relationship_search_path, params: { memory_query: "conversation" }

    fragment = Nokogiri::HTML5.fragment(response.body)
    expect(fragment.css("a[href='#{edit_relationship_profile_conversation_recap_path(profile, recap)}']").size).to eq(1)
    expect(response.body).not_to include(edit_relationship_profile_timeline_entry_path(profile, recap.timeline_entry))
    expect(response.body).not_to include("Translation missing")
  end

  it "groups owner-scoped results by relationship and links to their source records" do
    user = create(:user)
    profile = create(:relationship_profile, user:, first_name: "Ana", last_name: "Torres")
    preference = create(:relationship_preference, relationship_profile: profile, key: "Weekends", value: "Hiking")
    gift = create(:gift, relationship_profile: profile, name: "Hiking daypack")
    hidden_profile = create(:relationship_profile, first_name: "Hidden")
    create(:relationship_preference, relationship_profile: hidden_profile, key: "Weekends", value: "Hiking")
    sign_in user

    post relationship_search_path, params: { memory_query: "hiking", source: "all" }

    fragment = Nokogiri::HTML5.fragment(response.body)
    result_group = fragment.at_css("section[data-relationship-id='#{profile.id}']")

    expect(response).to have_http_status(:ok)
    expect(result_group).to be_present
    expect(result_group.text).to include(profile.display_name, "Hiking", "Hiking daypack")
    preference_anchor = ActionView::RecordIdentifier.dom_id(preference, :fields)
    expect(result_group.at_css("a[href='#{edit_relationship_profile_path(profile, anchor: preference_anchor)}']")).to be_present
    expect(result_group.at_css("a[href='#{edit_relationship_profile_gift_path(profile, gift)}']")).to be_present
    expect(response.body).not_to include("Hidden")
  end

  it "pluralizes result and relationship counts independently in both locales" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create_list(:gift, 2, relationship_profile: profile, name: "Hiking guide")
    sign_in user

    I18n.with_locale(:en) do
      post relationship_search_path, params: { memory_query: "hiking", source: "gifts" }

      expect(response.body).to include("2 results across 1 relationship")
    end

    I18n.with_locale(:es) do
      post relationship_search_path, params: { memory_query: "hiking", source: "gifts" }

      expect(response.body).to include("2 resultados en 1 relación")
    end
  end

  it "renders the complete search surface in Spanish" do
    sign_in create(:user)

    I18n.with_locale(:es) do
      get relationship_search_path
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("relationship_searches.show.heading", locale: :es))
    expect(response.body).to include(I18n.t("relationship_searches.show.search_label", locale: :es))
    expect(response.body).to include(I18n.t("relationship_searches.show.vault_notice", locale: :es))
    expect(response.body).not_to include("Translation missing")
  end

  it "handles malformed query parameters without exposing records" do
    user = create(:user)
    create(:relationship_profile, user:, first_name: "Ana")
    sign_in user

    post relationship_search_path, params: { memory_query: { nested: "Ana" }, source: [ "profiles" ], relationship_id: { nested: "bad" } }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("relationship_searches.show.empty_title"))
  end
end
