require "rails_helper"

RSpec.describe "Automation permissions", type: :request do
  it "requires authentication" do
    get edit_automation_permissions_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "renders the localized capability ledger and only owned relationships" do
    user = create(:user)
    owned_profile = create(:relationship_profile, user:, preferred_name: "Elena")
    create(:relationship_profile, preferred_name: "Private person")
    create(
      :automation_permission,
      user:,
      relationship_profile: owned_profile,
      capability: "make_reservations",
      mode: "ask_every_time"
    )
    sign_in user

    I18n.with_locale(:es) do
      get edit_automation_permissions_path(capability: "make_reservations")
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Permisos de automatización")
    expect(response.body).to include("Elena")
    expect(response.body).not_to include("Private person")

    document = Nokogiri::HTML(response.body)
    panel = document.at_css('[data-capability-panel="make_reservations"]')
    expect(panel.css('input[name^="automation_permissions[modes]"]')).to be_empty
    expect(panel.css('details[data-automation-permission-override]').size).to eq(1)
    expect(panel.css('input[name="automation_permission[mode]"]')).not_to be_empty
  end

  it "saves account defaults and audit events" do
    user = create(:user)
    sign_in user

    patch automation_permissions_path, params: {
      automation_permissions: {
        modes: {
          draft_messages: "allow_automatically",
          make_purchases: "ask_every_time"
        }
      },
      selected_capability: "make_purchases"
    }

    expect(response).to redirect_to(edit_automation_permissions_path(capability: "make_purchases"))
    expect(user.automation_permissions.pluck(:capability, :mode)).to contain_exactly(
      [ "draft_messages", "allow_automatically" ],
      [ "make_purchases", "ask_every_time" ]
    )
    expect(user.automation_permission_changes.count).to eq(2)
  end

  it "rejects a forged automatic high-impact mode without partial writes" do
    user = create(:user)
    sign_in user

    patch automation_permissions_path, params: {
      automation_permissions: {
        modes: {
          draft_messages: "ask_every_time",
          make_purchases: "allow_automatically"
        }
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.automation_permissions.reload).to be_empty
    expect(user.automation_permission_changes.reload).to be_empty
  end

  it "creates, updates, and removes an owned relationship override with an audit trail" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    sign_in user

    post automation_permission_overrides_path, params: {
      automation_permission: {
        capability: "make_reservations",
        relationship_profile_id: profile.id,
        mode: "ask_every_time"
      }
    }

    override = user.automation_permissions.relationship_overrides.sole
    expect(response).to redirect_to(edit_automation_permissions_path(capability: "make_reservations"))

    patch automation_permission_override_path(override), params: {
      automation_permission: { mode: "allow_automatically" }
    }
    expect(override.reload.mode).to eq("allow_automatically")

    delete automation_permission_override_path(override)

    expect { override.reload }.to raise_error(ActiveRecord::RecordNotFound)
    expect(user.automation_permission_changes.pluck(:action)).to eq(%w[created updated removed])
  end

  it "returns not found for another user's relationship and override" do
    user = create(:user)
    foreign_profile = create(:relationship_profile)
    foreign_override = create(
      :automation_permission,
      user: foreign_profile.user,
      relationship_profile: foreign_profile,
      capability: "make_reservations"
    )
    sign_in user

    post automation_permission_overrides_path, params: {
      automation_permission: {
        capability: "make_reservations",
        relationship_profile_id: foreign_profile.id,
        mode: "ask_every_time"
      }
    }
    expect(response).to have_http_status(:not_found)

    patch automation_permission_override_path(foreign_override), params: {
      automation_permission: { mode: "disabled" }
    }
    expect(response).to have_http_status(:not_found)
    expect(user.automation_permissions).to be_empty
  end

  it "hides archived overrides and rejects direct mutations" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Archived Elena")
    override = create(
      :automation_permission,
      user:,
      relationship_profile: profile,
      capability: "make_reservations",
      mode: "ask_every_time"
    )
    profile.discard!
    sign_in user

    get edit_automation_permissions_path(capability: "make_reservations")

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Archived Elena")

    patch automation_permission_override_path(override), params: {
      automation_permission: { mode: "allow_automatically" }
    }
    expect(response).to have_http_status(:not_found)

    delete automation_permission_override_path(override)
    expect(response).to have_http_status(:not_found)
    expect(override.reload.mode).to eq("ask_every_time")
    expect(AutomationPermissionChange.count).to eq(0)
  end
end
