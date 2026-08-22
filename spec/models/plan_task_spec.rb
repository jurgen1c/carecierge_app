require "rails_helper"

# == Schema Information
#
# Table name: plan_tasks
# Database name: primary
#
#  id             :uuid             not null, primary key
#  completed_at   :datetime
#  details        :text
#  due_on         :date
#  kind           :string           not null
#  lock_version   :integer          default(0), not null
#  origin         :string           default("manual"), not null
#  phase          :string           not null
#  position       :integer          not null
#  source_context :text             not null
#  title          :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  event_plan_id  :uuid             not null
#
# Indexes
#
#  index_plan_tasks_on_event_plan_id            (event_plan_id)
#  index_plan_tasks_on_plan_completion_and_due  (event_plan_id,completed_at,due_on)
#  index_plan_tasks_on_plan_phase_position      (event_plan_id,phase,position)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#
RSpec.describe PlanTask, type: :model do
  subject(:plan_task) { build(:plan_task) }

  it { is_expected.to belong_to(:event_plan) }
  it { is_expected.to have_many(:reminders).dependent(:nullify) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_inclusion_of(:phase).in_array(PlanTask::PHASES) }
  it { is_expected.to validate_inclusion_of(:kind).in_array(PlanTask::KINDS) }
  it { is_expected.to validate_inclusion_of(:origin).in_array(PlanTask::ORIGINS) }

  it "normalizes user-authored text" do
    plan_task.title = "  Confirm   the venue "
    plan_task.details = "  Ask about accessibility.  \n"

    plan_task.validate

    expect(plan_task).to have_attributes(title: "Confirm the venue", details: "Ask about accessibility.")
  end

  it "completes idempotently and retires its active reminders" do
    plan_task = create(:plan_task)
    reminder = create(
      :reminder,
      user: plan_task.event_plan.user,
      relationship_profile: plan_task.event_plan.relationship_profile,
      event_plan: plan_task.event_plan,
      plan_task:
    )
    completed_at = Time.zone.local(2026, 9, 1, 10)

    plan_task.complete!(at: completed_at)
    plan_task.complete!(at: completed_at + 1.hour)

    expect(plan_task.reload.completed_at).to eq(completed_at)
    expect(reminder.reload).to have_attributes(status: "completed", completed_at: completed_at)
  end

  it "reopens without reactivating historical reminders" do
    plan_task = create(:plan_task)
    reminder = create(
      :reminder,
      user: plan_task.event_plan.user,
      relationship_profile: plan_task.event_plan.relationship_profile,
      event_plan: plan_task.event_plan,
      plan_task:
    )
    plan_task.complete!

    generation_version = plan_task.event_plan.reload.generation_version
    plan_task.reopen!
    plan_task.reopen!

    expect(plan_task.reload.completed_at).to be_nil
    expect(reminder.reload).to be_completed
    expect(plan_task.event_plan.reload.generation_version).to eq(generation_version + 1)
  end

  it "detaches reminders without deleting their delivery history when destroyed" do
    plan_task = create(:plan_task)
    reminder = create(
      :reminder,
      user: plan_task.event_plan.user,
      relationship_profile: plan_task.event_plan.relationship_profile,
      event_plan: plan_task.event_plan,
      plan_task:
    )

    expect { plan_task.destroy! }.not_to change(Reminder, :count)

    expect(reminder.reload).to have_attributes(event_plan: plan_task.event_plan, plan_task: nil)
  end
end
