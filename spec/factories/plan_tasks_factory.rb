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
FactoryBot.define do
  factory :plan_task do
    association :event_plan
    phase { "decide" }
    kind { "task" }
    title { "Confirm the guest list" }
    details { "Check availability before booking." }
    due_on { Date.new(2026, 9, 1) }
    sequence(:position)
    origin { "manual" }
    source_context { [] }
  end
end
