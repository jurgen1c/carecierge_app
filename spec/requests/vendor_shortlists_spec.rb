require "rails_helper"

RSpec.describe "Vendor shortlists", type: :request do
  it "creates a relationship shortlist from saved vendors without JavaScript" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    vendors = create_list(:vendor, 2, user:)
    sign_in user

    expect do
      post vendor_shortlists_path, params: {
        vendor_shortlist: {
          title: "Birthday dinner",
          relationship_profile_id: profile.id,
          vendor_ids: vendors.map(&:id)
        }
      }
    end.to change(VendorShortlist, :count).by(1).and change(VendorOption, :count).by(2)

    shortlist = user.vendor_shortlists.sole
    expect(response).to redirect_to(vendor_shortlist_path(shortlist))
    expect(shortlist.vendors).to contain_exactly(*vendors)
  end

  it "creates an event-plan shortlist and derives its relationship" do
    plan = create(:event_plan)
    vendor = create(:vendor, user: plan.user)
    sign_in plan.user

    post vendor_shortlists_path, params: {
      vendor_shortlist: { title: "Plan vendors", event_plan_id: plan.id, vendor_ids: [ vendor.id ] }
    }

    shortlist = plan.vendor_shortlists.sole
    expect(shortlist.relationship_profile_id).to eq(plan.relationship_profile_id)
    expect(shortlist.vendors).to contain_exactly(vendor)
  end

  it "renders validation errors when no relationship or event plan is selected" do
    user = create(:user)
    sign_in user

    expect do
      post vendor_shortlists_path, params: { vendor_shortlist: { title: "Missing context" } }
    end.not_to change(VendorShortlist, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Relationship must exist")
  end

  it "does not create with foreign relationship, plan, or vendor records" do
    user = create(:user)
    foreign_profile = create(:relationship_profile)
    foreign_plan = create(:event_plan)
    foreign_vendor = create(:vendor)
    sign_in user

    [
      { relationship_profile_id: foreign_profile.id },
      { event_plan_id: foreign_plan.id },
      { relationship_profile_id: create(:relationship_profile, user:).id, vendor_ids: [ foreign_vendor.id ] }
    ].each do |context|
      expect do
        post vendor_shortlists_path, params: { vendor_shortlist: { title: "Private", **context } }
      end.not_to change(VendorShortlist, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "rejects more than five vendor IDs before loading them and preserves the checked vendors" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    vendors = create_list(:vendor, VendorShortlist::MAX_OPTIONS + 1, user:)
    sign_in user

    expect do
      post vendor_shortlists_path, params: {
        vendor_shortlist: {
          title: "Birthday dinner",
          relationship_profile_id: profile.id,
          vendor_ids: vendors.map(&:id)
        }
      }
    end.not_to change(VendorShortlist, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("can include at most 5 vendors")
    vendors.each do |vendor|
      expect(response.body).to match(/value="#{vendor.id}"[^>]*checked="checked"/)
    end
  end

  it "shows all comparison dimensions, preserves source links, and avoids external actions" do
    option = create(
      :vendor_option,
      notes: "A trusted recommendation.",
      constraints: "Confirm the deposit.",
      next_action: "Review cancellation terms."
    )
    option.vendor.update!(source_kind: "external", source_name: "Vendor site", source_url: "https://example.com/source")
    sign_in option.vendor_shortlist.user

    get vendor_shortlist_path(option.vendor_shortlist)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      "Price range",
      "Availability",
      "Location",
      "Why it may fit",
      "Notes",
      "Constraints",
      "Next action",
      "https://example.com/source"
    )
    expect(response.body).not_to include("Book vendor", "Contact vendor", "Purchase")
  end

  it "exempts every private shortlist surface from Turbo snapshot caching" do
    shortlist = create(:vendor_shortlist)
    sign_in shortlist.user

    [ vendor_shortlists_path, new_vendor_shortlist_path, vendor_shortlist_path(shortlist) ].each do |path|
      get path

      expect(response.parsed_body.at_css("meta[name='turbo-cache-control']")&.[]("content")).to eq("no-cache")
    end
  end

  it "paginates the owner shortlist index twenty records at a time" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    old_shortlist = create(
      :vendor_shortlist,
      :relationship_need,
      user:,
      relationship_profile: profile,
      title: "Oldest shortlist",
      created_at: 21.days.ago
    )
    create_list(:vendor_shortlist, 20, :relationship_need, user:, relationship_profile: profile)
    sign_in user

    get vendor_shortlists_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(old_shortlist.title)
    expect(response.body).to include("Page 1 of 2", "Next")

    get vendor_shortlists_path(page: 2)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(old_shortlist.title, "Page 2 of 2", "Previous")
  end

  it "adds and edits owner-scoped options, favorites, rejects, selects, and restores them" do
    shortlist = create(:vendor_shortlist)
    first_vendor, second_vendor = create_list(:vendor, 2, user: shortlist.user)
    sign_in shortlist.user

    post vendor_shortlist_vendor_options_path(shortlist), params: { vendor_option: { vendor_id: first_vendor.id } }
    first = shortlist.vendor_options.sole

    patch vendor_shortlist_vendor_option_path(shortlist, first), params: {
      vendor_option: {
        notes: "Preferred",
        constraints: "Deposit",
        next_action: "Review quote",
        lock_version: first.lock_version
      }
    }
    patch favorite_vendor_shortlist_vendor_option_path(shortlist, first)
    patch select_vendor_shortlist_vendor_option_path(shortlist, first)

    post vendor_shortlist_vendor_options_path(shortlist), params: { vendor_option: { vendor_id: second_vendor.id } }
    second = shortlist.vendor_options.find_by!(vendor: second_vendor)
    patch select_vendor_shortlist_vendor_option_path(shortlist, second)
    patch reject_vendor_shortlist_vendor_option_path(shortlist, second)
    patch restore_vendor_shortlist_vendor_option_path(shortlist, second)

    expect(first.reload).to have_attributes(
      notes: "Preferred",
      constraints: "Deposit",
      next_action: "Review quote",
      favorite: true,
      decision: "considering"
    )
    expect(second.reload).to have_attributes(decision: "considering")
  end

  it "rejects stale and unversioned comparison-note updates without overwriting newer private data" do
    option = create(:vendor_option, notes: "Original note")
    rendered_lock_version = option.lock_version
    option.update!(notes: "Newer saved note")
    sign_in option.vendor_shortlist.user

    patch vendor_shortlist_vendor_option_path(option.vendor_shortlist, option), params: {
      vendor_option: { notes: "Stale overwrite", lock_version: rendered_lock_version }
    }

    expect(response).to redirect_to(vendor_shortlist_path(option.vendor_shortlist))
    expect(flash[:alert]).to eq("The comparison changed before your notes were saved. Review it and try again.")
    expect(option.reload.notes).to eq("Newer saved note")

    patch vendor_shortlist_vendor_option_path(option.vendor_shortlist, option), params: {
      vendor_option: { notes: "Unversioned overwrite" }
    }

    expect(response).to have_http_status(:bad_request)
    expect(option.reload.notes).to eq("Newer saved note")
  end

  it "does not mutate an option through another shortlist or owner" do
    owned_shortlist = create(:vendor_shortlist)
    foreign_option = create(:vendor_option)
    sign_in owned_shortlist.user

    expect do
      patch favorite_vendor_shortlist_vendor_option_path(owned_shortlist, foreign_option)
    end.not_to change { foreign_option.reload.favorite }
    expect(response).to have_http_status(:not_found)
  end

  it "renders a read-only completed-plan shortlist and rejects mutations" do
    option = create(:vendor_option)
    shortlist = option.vendor_shortlist
    shortlist.event_plan.complete!
    sign_in shortlist.user

    get vendor_shortlist_path(shortlist)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Comparison details are read-only")

    expect do
      patch favorite_vendor_shortlist_vendor_option_path(shortlist, option)
    end.not_to change { option.reload.favorite }
    expect(response).to have_http_status(:not_found)
  end

  it "allows explicit option removal after an event plan is archived" do
    option = create(:vendor_option, notes: "Owner-authored comparison")
    shortlist = option.vendor_shortlist
    shortlist.event_plan.archive!
    sign_in shortlist.user

    get vendor_shortlist_path(shortlist)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Comparison details are read-only", "Remove from shortlist")

    expect do
      delete vendor_shortlist_vendor_option_path(shortlist, option)
    end.to change(VendorOption, :count).by(-1)

    expect(response).to redirect_to(vendor_shortlist_path(shortlist))
    expect(option.vendor.reload).to be_persisted
  end

  it "keeps an invalid removal render read-only when its event plan is archived" do
    option = create(:vendor_option)
    shortlist = option.vendor_shortlist
    shortlist.event_plan.archive!
    option.errors.add(:base, "Could not remove this option")
    allow_any_instance_of(VendorOption).to receive(:remove!).and_raise(ActiveRecord::RecordInvalid, option)
    sign_in shortlist.user

    delete vendor_shortlist_vendor_option_path(shortlist, option)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Could not remove this option", "Remove from shortlist")
    expect(response.body).not_to include("Save comparison notes", "Mark as favorite", "Select vendor")
  end

  it "keeps an archived relationship shortlist reachable for explicit option removal" do
    option = create(:vendor_option, notes: "Owner-authored comparison")
    shortlist = option.vendor_shortlist
    shortlist.relationship_profile.discard!
    sign_in shortlist.user

    get vendor_shortlist_path(shortlist)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Comparison details are read-only", "Remove from shortlist")

    expect do
      delete vendor_shortlist_vendor_option_path(shortlist, option)
    end.to change(VendorOption, :count).by(-1)

    expect(response).to redirect_to(vendor_shortlist_path(shortlist))
    expect(option.vendor.reload).to be_persisted
  end

  it "renders the workflow in Spanish" do
    shortlist = create(:vendor_shortlist)
    create(:vendor_option, vendor_shortlist: shortlist)
    sign_in shortlist.user

    I18n.with_locale(:es) { get vendor_shortlist_path(shortlist) }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Comparar proveedores", "Carecierge no contacta ni reserva proveedores")
    expect(response.body).not_to include("Translation missing")
  end
end
