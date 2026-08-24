require "rails_helper"

# == Schema Information
#
# Table name: event_plans
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  budget_cents            :integer
#  completed_at            :datetime
#  effort_level            :string           default("medium"), not null
#  generation_version      :bigint           default(0), not null
#  guest_list              :text
#  lock_version            :integer          default(0), not null
#  notes                   :text
#  occasion_type           :string           not null
#  source_context          :text             not null
#  starts_on               :date
#  status                  :string           default("active"), not null
#  title                   :text             not null
#  tone                    :string           default("warm"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_event_plans_on_profile_status_and_start          (relationship_profile_id,status,starts_on)
#  index_event_plans_on_relationship_profile_id           (relationship_profile_id)
#  index_event_plans_on_user_id                           (user_id)
#  index_event_plans_on_user_id_and_status_and_starts_on  (user_id,status,starts_on)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
RSpec.describe EventPlan, type: :model do
  subject(:event_plan) { build(:event_plan) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:relationship_profile) }
  it { is_expected.to have_many(:plan_tasks).dependent(:destroy) }
  it { is_expected.to have_many(:reminders).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_inclusion_of(:occasion_type).in_array(EventPlan::OCCASION_TYPES) }
  it { is_expected.to validate_inclusion_of(:status).in_array(EventPlan::STATUSES) }

  it "validates the user-adjustable planning tone and effort" do
    event_plan.tone = "cheesy"
    event_plan.effort_level = "impossible"

    expect(event_plan).not_to be_valid
    expect(event_plan.errors.of_kind?(:tone, :inclusion)).to be(true)
    expect(event_plan.errors.of_kind?(:effort_level, :inclusion)).to be(true)
  end

  it "requires the plan and relationship to have the same owner" do
    event_plan.relationship_profile = create(:relationship_profile)

    expect(event_plan).not_to be_valid
    expect(event_plan.errors.of_kind?(:relationship_profile, :owner_mismatch)).to be(true)
  end

  it "normalizes authored fields" do
    event_plan.title = "  Maya's   birthday dinner "
    event_plan.notes = "  Keep it relaxed.  \n"
    event_plan.guest_list = "  Maya, Alex  "

    event_plan.validate

    expect(event_plan).to have_attributes(
      title: "Maya's birthday dinner",
      notes: "Keep it relaxed.",
      guest_list: "Maya, Alex"
    )
  end

  it "rejects budgets outside the PostgreSQL integer range" do
    event_plan.budget_cents = 2_147_483_648

    expect(event_plan).not_to be_valid
    expect(event_plan.errors.of_kind?(:budget_cents, :less_than_or_equal_to)).to be(true)
  end

  it "reports progress and outstanding decisions from its plan tasks" do
    event_plan = create(:event_plan)
    create(:plan_task, event_plan:, kind: "decision", completed_at: nil)
    create(:plan_task, event_plan:, kind: "task", completed_at: Time.current)
    create(:plan_task, event_plan:, kind: "task", completed_at: nil)

    expect(event_plan.progress).to eq(completed: 1, total: 3, percentage: 33)
    expect(event_plan.outstanding_decisions.map(&:kind)).to eq([ "decision" ])
  end

  it "reports the earliest due incomplete current task as the next action" do
    event_plan = create(:event_plan)
    create(:plan_task, event_plan:, title: "Completed", due_on: Date.new(2026, 8, 20), completed_at: Time.current)
    create(:plan_task, event_plan:, title: "Later", due_on: Date.new(2026, 9, 1), position: 1)
    expected = create(:plan_task, event_plan:, title: "Next", due_on: Date.new(2026, 8, 25), position: 2)
    create(:plan_task, event_plan:, title: "Superseded", due_on: Date.new(2026, 8, 22), superseded_at: Time.current, position: 3)
    create(:plan_task, event_plan:, title: "Unscheduled", due_on: nil, position: 0)

    expect(event_plan.next_action).to eq(expected)
  end

  it "retires active reminders when completed without reactivating them when reopened" do
    event_plan = create(:event_plan)
    reminder = create(:reminder, user: event_plan.user, relationship_profile: event_plan.relationship_profile, event_plan:)
    completed_at = Time.zone.local(2026, 9, 12, 21)

    event_plan.complete!(at: completed_at)

    expect(reminder.reload).to have_attributes(status: "completed", completed_at:, next_delivery_at: nil)

    event_plan.reopen!

    expect(reminder.reload).to be_completed
  end

  it "keeps terminal transitions idempotent and rejects invalid lifecycle transitions" do
    completed = create(:event_plan, status: "completed", completed_at: Time.current)
    archived = create(:event_plan, status: "archived")
    active = create(:event_plan)

    expect { completed.complete! }.not_to change(completed, :updated_at)
    expect { archived.archive! }.not_to change(archived, :updated_at)
    expect { archived.complete! }.to raise_error(ActiveRecord::RecordInvalid)
    expect { active.reopen! }.not_to change(active, :updated_at)
  end

  it "advances the generation fence for each lifecycle transition" do
    event_plan = create(:event_plan)

    expect { event_plan.complete! }.to change(event_plan, :generation_version).by(1)
    expect { event_plan.reopen! }.to change(event_plan, :generation_version).by(1)
    expect { event_plan.archive! }.to change(event_plan, :generation_version).by(1)
    expect { event_plan.archive! }.not_to change(event_plan, :generation_version)
  end

  it "defaults missing provenance and rejects malformed provenance" do
    without_sources = build(:event_plan, source_context: nil)
    malformed = build(:event_plan, source_context: [ { "label" => "Missing id" } ])

    expect(without_sources).to be_valid
    expect(without_sources.source_context).to eq([])
    expect(malformed).not_to be_valid
    expect(malformed.errors.of_kind?(:source_context, :invalid)).to be(true)
  end

  it "requires a birthday-origin plan to remain a birthday" do
    event_plan.source_context = [
      {
        "id" => "important_date:#{SecureRandom.uuid}",
        "label" => "Important date",
        "role" => "birthday_origin"
      }
    ]
    event_plan.occasion_type = "custom"

    expect(event_plan).not_to be_valid
    expect(event_plan.errors.of_kind?(:occasion_type, :birthday_origin_immutable)).to be(true)
  end

  it "requires an anniversary-origin plan to remain an anniversary" do
    event_plan.source_context = [
      {
        "id" => "important_date:#{SecureRandom.uuid}",
        "label" => "Important date",
        "role" => "anniversary_origin",
        "date_type" => "milestone"
      }
    ]
    event_plan.occasion_type = "custom"

    expect(event_plan).not_to be_valid
    expect(event_plan.errors.of_kind?(:occasion_type, :anniversary_origin_immutable)).to be(true)
  end

  it "requires a plan with selected prior anniversary context to remain an anniversary" do
    event_plan.source_context = [
      {
        "id" => "event_plan:#{SecureRandom.uuid}",
        "label" => "Prior anniversary plan — review before reusing",
        "role" => "prior_anniversary_context",
        "certainty" => "needs_confirmation"
      }
    ]
    event_plan.occasion_type = "custom"

    expect(event_plan).not_to be_valid
    expect(event_plan.errors.of_kind?(:occasion_type, :prior_anniversary_context_immutable)).to be(true)
  end
end
