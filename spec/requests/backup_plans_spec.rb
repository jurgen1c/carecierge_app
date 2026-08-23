require "rails_helper"

RSpec.describe "Backup plans", type: :request do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:event_plan) { create(:event_plan, user:, relationship_profile: profile) }

  it "passes the scenario and explicit per-request source choices to generation" do
    private_note = create(:relationship_note, relationship_profile: profile, private: true, body: "Keep this small")
    allow(BackupPlans::Generate).to receive(:call).and_return(create(:backup_plan, user:, event_plan:))
    sign_in user

    post generate_event_plan_backup_plans_path(event_plan), params: {
      backup_plan: { scenario: "weather", private_note_ids: [ private_note.id ] }
    }

    expect(response).to redirect_to(event_plan_path(event_plan, anchor: "backup-options"))
    expect(BackupPlans::Generate).to have_received(:call).with(hash_including(
      actor: user,
      event_plan: have_attributes(id: event_plan.id),
      scenario: "weather",
      private_note_ids: [ private_note.id ],
      vault_item_ids: [],
      locale: :en
    ))
  end

  it "does not expose another account's plan or option" do
    backup_plan = create(:backup_plan, user:, event_plan:)
    option = create(:backup_option, backup_plan:)
    sign_in create(:user)

    post generate_event_plan_backup_plans_path(event_plan), params: { backup_plan: { scenario: "weather" } }
    patch promote_event_plan_backup_plan_path(event_plan, backup_plan), params: { option_id: option.id }

    expect(response).to have_http_status(:not_found)
    expect(backup_plan.reload).to be_generated
  end

  it "requires an active vault lease before protected context reaches generation" do
    vault_item = create(
      :privacy_vault_item,
      relationship_profile: profile,
      suggestion_usage: "allowed"
    )
    allow(BackupPlans::Generate).to receive(:call)
    sign_in user

    post generate_event_plan_backup_plans_path(event_plan), params: {
      backup_plan: { scenario: "weather", vault_item_ids: [ vault_item.id ] }
    }

    expect(response).to redirect_to(relationship_profile_privacy_vault_path(profile))
    expect(BackupPlans::Generate).not_to have_received(:call)
  end

  it "promotes an owner-scoped option" do
    backup_plan = create(
      :backup_plan,
      user:,
      event_plan:,
      event_plan_generation_version: event_plan.generation_version
    )
    option = create(:backup_option, backup_plan:)
    allow(BackupPlans::Promote).to receive(:call).and_return(option)
    sign_in user

    patch promote_event_plan_backup_plan_path(event_plan, backup_plan), params: { option_id: option.id }

    expect(response).to redirect_to(event_plan_path(event_plan, anchor: "backup-options"))
    expect(BackupPlans::Promote).to have_received(:call).with(
      actor: user,
      backup_option: option,
      vault_lease: nil
    )
  end

  it "requires a current vault lease before promoting protected-context options" do
    backup_plan = create(:backup_plan, user:, event_plan:, include_vault_context: true)
    option = create(:backup_option, backup_plan:)
    allow(BackupPlans::Promote).to receive(:call)
    sign_in user

    patch promote_event_plan_backup_plan_path(event_plan, backup_plan), params: { option_id: option.id }

    expect(response).to redirect_to(relationship_profile_privacy_vault_path(profile))
    expect(BackupPlans::Promote).not_to have_received(:call)
  end

  it "replays an already-promoted protected option without requiring a fresh vault lease" do
    promoted_at = 1.minute.ago
    backup_plan = create(
      :backup_plan,
      user:,
      event_plan:,
      include_vault_context: true,
      status: "promoted",
      promoted_at:
    )
    option = create(:backup_option, backup_plan:, promoted_at:)
    original_promoted_at = option.reload.promoted_at
    sign_in user

    patch promote_event_plan_backup_plan_path(event_plan, backup_plan), params: { option_id: option.id }

    expect(response).to redirect_to(event_plan_path(event_plan, anchor: "backup-options"))
    expect(option.reload.promoted_at).to eq(original_promoted_at)
  end
end
