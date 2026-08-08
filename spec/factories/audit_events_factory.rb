# == Schema Information
#
# Table name: audit_events
# Database name: primary
#
#  id          :uuid             not null, primary key
#  action      :string           not null
#  actor_kind  :string           not null
#  metadata    :jsonb            not null
#  occurred_at :datetime         not null
#  source      :string           not null
#  target_type :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  actor_id    :uuid
#  target_id   :uuid
#  user_id     :uuid             not null
#
# Indexes
#
#  index_audit_events_on_action_and_occurred_at     (action,occurred_at DESC)
#  index_audit_events_on_actor_id                   (actor_id)
#  index_audit_events_on_source_and_occurred_at     (source,occurred_at DESC)
#  index_audit_events_on_target_type_and_target_id  (target_type,target_id)
#  index_audit_events_on_user_id                    (user_id)
#  index_audit_events_on_user_id_and_occurred_at    (user_id,occurred_at DESC)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => users.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :audit_event do
    association :user
    actor { user }
    actor_kind { "user" }
    action { "relationship_profile.updated" }
    source { "web_app" }
    occurred_at { Time.current }
    metadata { {} }
  end
end
