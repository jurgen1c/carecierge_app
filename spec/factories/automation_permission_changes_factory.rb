# == Schema Information
#
# Table name: automation_permission_changes
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  action                  :string           not null
#  capability              :string           not null
#  new_mode                :string
#  previous_mode           :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  actor_id                :uuid             not null
#  relationship_profile_id :uuid
#  user_id                 :uuid             not null
#
# Indexes
#
#  idx_automation_permission_changes_relationship_time             (relationship_profile_id,created_at)
#  index_automation_permission_changes_on_actor_id                 (actor_id)
#  index_automation_permission_changes_on_relationship_profile_id  (relationship_profile_id)
#  index_automation_permission_changes_on_user_id                  (user_id)
#  index_automation_permission_changes_on_user_id_and_created_at   (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :automation_permission_change do
    user
    actor { user }
    capability { "draft_messages" }
    action { "updated" }
    previous_mode { "disabled" }
    new_mode { "ask_every_time" }
  end
end
