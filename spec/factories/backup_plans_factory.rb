# == Schema Information
#
# Table name: backup_plans
# Database name: primary
#
#  id                            :uuid             not null, primary key
#  event_plan_generation_version :bigint           not null
#  generated_at                  :datetime         not null
#  include_private_notes         :boolean          default(FALSE), not null
#  include_vault_context         :boolean          default(FALSE), not null
#  locale                        :string           default("en"), not null
#  lock_version                  :integer          default(0), not null
#  promoted_at                   :datetime
#  scenario                      :string           not null
#  source_context                :text             not null
#  status                        :string           default("generated"), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  event_plan_id                 :uuid             not null
#  user_id                       :uuid             not null
#
# Indexes
#
#  index_backup_plans_on_event_plan_id          (event_plan_id)
#  index_backup_plans_on_plan_status_generated  (event_plan_id,status,generated_at)
#  index_backup_plans_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :backup_plan do
    association :user
    event_plan { association(:event_plan, user:) }
    scenario { "weather" }
    source_context do
      [
        {
          "id" => "profile:#{event_plan.relationship_profile_id}",
          "label" => "Relationship",
          "certainty" => "confirmed",
          "sensitive" => false
        }
      ]
    end
    locale { "en" }
    status { "generated" }
    event_plan_generation_version { event_plan.generation_version }
    context_fingerprint { "0" * 64 }
    generated_at { Time.current }
  end
end
