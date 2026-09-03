require "rails_helper"

RSpec.describe BackupPlans::Promote do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:event_plan) { create(:event_plan, user:, relationship_profile: profile) }
  let!(:replaceable_task) { create(:plan_task, event_plan:, title: "Confirm outdoor venue") }
  let!(:completed_task) { create(:plan_task, event_plan:, title: "Invite family", completed_at: 1.day.ago) }
  let!(:reminder) do
    create(:reminder, user:, relationship_profile: profile, event_plan:, plan_task: replaceable_task)
  end
  let(:backup_plan) do
    create(
      :backup_plan,
      user:,
      event_plan:,
      event_plan_generation_version: event_plan.generation_version,
      context_fingerprint: EventPlans::ContextBuilder.new(event_plan:).call.fingerprint
    )
  end
  let(:backup_option) do
    create(
      :backup_option,
      backup_plan:,
      replacement_task_ids: [ replaceable_task.id ],
      task_blueprints: [
        {
          "phase" => "arrange",
          "kind" => "backup_step",
          "title" => "Confirm the indoor venue",
          "details" => "Keep the same date and guest list.",
          "due_on" => "2026-09-10",
          "source_context" => [
            {
              "id" => "profile:#{profile.id}",
              "label" => "Relationship",
              "certainty" => "confirmed",
              "sensitive" => false
            }
          ]
        }
      ]
    )
  end

  it "promotes once while preserving completed work and reminder history" do
    expect do
      described_class.call(actor: user, backup_option:, at: Time.zone.parse("2026-08-22 10:00:00"))
    end.to change { event_plan.plan_tasks.count }.by(1)

    promoted_task = event_plan.plan_tasks.reorder(created_at: :desc, id: :desc).first
    expect(promoted_task).to have_attributes(
      title: "Confirm the indoor venue",
      origin: "ai",
      kind: "backup_step",
      backup_option_id: backup_option.id
    )
    expect(replaceable_task.reload.superseded_at).to be_present
    expect(completed_task.reload.superseded_at).to be_nil
    expect(reminder.reload).to be_completed
    expect(reminder.plan_task_id).to be_nil
    expect(backup_plan.reload).to be_promoted
    expect(backup_option.reload.promoted_at).to be_present

    expect do
      described_class.call(actor: user, backup_option:)
    end.not_to change(PlanTask, :count)
  end

  it "keeps completed reminder history attached to the superseded task" do
    completed_reminder = create(
      :reminder,
      user:,
      relationship_profile: profile,
      event_plan:,
      plan_task: replaceable_task,
      status: "completed",
      completed_at: 1.day.ago,
      next_delivery_at: nil
    )

    described_class.call(actor: user, backup_option:)

    expect(completed_reminder.reload).to have_attributes(
      status: "completed",
      plan_task_id: replaceable_task.id
    )
  end

  it "promotes when unchanged reminder snapshots were reviewed in replacement-task order" do
    second_task = create(:plan_task, event_plan:, title: "Confirm catering")
    second_reminder = create(
      :reminder,
      user:,
      relationship_profile: profile,
      event_plan:,
      plan_task: second_task
    )
    option = create(
      :backup_option,
      backup_plan:,
      replacement_task_ids: [ second_task.id, replaceable_task.id ],
      reviewed_reminders: [ second_reminder, reminder ].map { |item| BackupOption.reminder_snapshot(item) }
    )

    expect do
      described_class.call(actor: user, backup_option: option)
    end.not_to raise_error

    expect([ second_task, replaceable_task ].map { |task| task.reload.superseded? }).to all(be(true))
    expect([ second_reminder, reminder ].map { |item| item.reload.completed? }).to all(be(true))
  end

  it "rejects promotion after the event plan changes" do
    backup_option
    EventPlans::Update.call(event_plan:, attributes: { notes: "Updated constraints" })

    previous_superseded_at = replaceable_task.reload.superseded_at
    expect do
      described_class.call(actor: user, backup_option:)
    end.to raise_error(BackupPlans::PromotionUnavailableError)
    expect(replaceable_task.reload.superseded_at).to eq(previous_superseded_at)
  end

  it "rejects replacement of a booking-owned task" do
    booking = create(:booking, user:, event_plan:)
    Bookings::Save.call(booking, attributes: {}, locale: :en)
    protected_plan = create(
      :backup_plan,
      user:,
      event_plan:,
      event_plan_generation_version: event_plan.reload.generation_version,
      context_fingerprint: EventPlans::ContextBuilder.new(event_plan:).call.fingerprint
    )
    protected_option = create(
      :backup_option,
      backup_plan: protected_plan,
      replacement_task_ids: [ booking.plan_task_id ]
    )

    expect do
      described_class.call(actor: user, backup_option: protected_option)
    end.to raise_error(BackupPlans::PromotionUnavailableError, "A replaced plan task is no longer available")
    expect(booking.plan_task.reload).not_to be_superseded
  end

  it "rejects promotion after authorized relationship context changes" do
    preference = create(:relationship_preference, relationship_profile: profile, value: "Quiet room")
    backup_plan.update!(
      context_fingerprint: EventPlans::ContextBuilder.new(event_plan:).call.fingerprint
    )
    generation_version = event_plan.generation_version
    preference.update!(value: "Outdoor space")

    expect(event_plan.reload.generation_version).to eq(generation_version)
    expect do
      described_class.call(actor: user, backup_option:)
    end.to raise_error(BackupPlans::PromotionUnavailableError)
    expect(replaceable_task.reload.superseded_at).to be_nil
  end

  it "rejects promotion when an active reminder was attached after review" do
    backup_option.update!(reviewed_reminders: [])
    late_reminder = create(
      :reminder,
      user:,
      relationship_profile: profile,
      event_plan:,
      plan_task: replaceable_task,
      title: "Added after options were reviewed"
    )

    expect do
      described_class.call(actor: user, backup_option:)
    end.to raise_error(BackupPlans::PromotionUnavailableError)
    expect(replaceable_task.reload.superseded_at).to be_nil
    expect(late_reminder.reload).to be_active
    expect(late_reminder.plan_task_id).to eq(replaceable_task.id)
  end

  it "revalidates unchanged context under the generation locale" do
    english_context = I18n.with_locale(:en) do
      EventPlans::ContextBuilder.new(event_plan:, locale: :en).call
    end
    backup_plan.update!(context_fingerprint: english_context.fingerprint, locale: "en")

    I18n.with_locale(:es) do
      expect do
        described_class.call(actor: user, backup_option:)
      end.not_to raise_error
    end

    expect(backup_option.reload.promoted_at).to be_present
  end

  it "rejects promotion after the relationship is archived while waiting for its lock" do
    backup_option
    allow_any_instance_of(RelationshipProfile).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      profile.update_column(:discarded_at, Time.current)
      method.call(*args, &block)
    end

    expect do
      described_class.call(actor: user, backup_option:)
    end.to raise_error(BackupPlans::PromotionUnavailableError)
    expect(replaceable_task.reload.superseded_at).to be_nil
  end

  it "records sensitive and vault access when promotion revalidates protected context" do
    vault_item = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "allowed")
    context = EventPlans::ContextBuilder.new(event_plan:, vault_item_ids: [ vault_item.id ]).call
    backup_plan.update!(
      source_context: context.sources.map { |source| source.to_h.stringify_keys },
      context_fingerprint: context.fingerprint,
      include_vault_context: true
    )
    lease = PrivacyVault::Lease.issue_for(user)

    expect do
      described_class.call(actor: user, backup_option:, vault_lease: lease)
    end.to change {
      AuditEvent.where(user:, action: "sensitive_record.accessed", target: profile).count
    }.by(1).and change {
      VaultAccessEvent.where(user:, relationship_profile: profile, event_type: "viewed").count
    }.by(1)
  end

  it "retains sensitive access evidence when protected context invalidates promotion" do
    vault_item = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "allowed")
    context = EventPlans::ContextBuilder.new(event_plan:, vault_item_ids: [ vault_item.id ]).call
    backup_plan.update!(
      source_context: context.sources.map { |source| source.to_h.stringify_keys },
      context_fingerprint: context.fingerprint,
      include_vault_context: true
    )
    create(:relationship_preference, relationship_profile: profile, value: "Changed after generation")
    lease = PrivacyVault::Lease.issue_for(user)

    expect do
      expect do
        described_class.call(actor: user, backup_option:, vault_lease: lease)
      end.to raise_error(BackupPlans::PromotionUnavailableError)
    end.to change {
      AuditEvent.where(user:, action: "sensitive_record.accessed", target: profile).count
    }.by(1).and change {
      VaultAccessEvent.where(user:, relationship_profile: profile, event_type: "viewed").count
    }.by(1)
    expect(replaceable_task.reload.superseded_at).to be_nil
  end

  it "retains vault access evidence when a selected item is no longer authorized for suggestions" do
    vault_item = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "allowed")
    context = EventPlans::ContextBuilder.new(event_plan:, vault_item_ids: [ vault_item.id ]).call
    backup_plan.update!(
      source_context: context.sources.map { |source| source.to_h.stringify_keys },
      context_fingerprint: context.fingerprint,
      include_vault_context: true
    )
    vault_item.update!(suggestion_usage: "excluded")
    lease = PrivacyVault::Lease.issue_for(user)

    expect do
      expect do
        described_class.call(actor: user, backup_option:, vault_lease: lease)
      end.to raise_error(BackupPlans::PromotionUnavailableError)
    end.to change {
      AuditEvent.where(user:, action: "sensitive_record.accessed", target: profile).count
    }.by(1).and change {
      VaultAccessEvent.where(user:, relationship_profile: profile, event_type: "viewed").count
    }.by(1)
    expect(replaceable_task.reload.superseded_at).to be_nil
  end

  it "fails closed for another user" do
    expect do
      described_class.call(actor: create(:user), backup_option:)
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
