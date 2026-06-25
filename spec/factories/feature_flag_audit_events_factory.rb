# == Schema Information
#
# Table name: feature_flag_audit_events
# Database name: primary
#
#  id              :uuid             not null, primary key
#  action          :string           not null
#  details         :jsonb            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  actor_id        :uuid
#  feature_flag_id :uuid             not null
#
# Indexes
#
#  index_feature_flag_audit_events_on_action           (action)
#  index_feature_flag_audit_events_on_actor_id         (actor_id)
#  index_feature_flag_audit_events_on_feature_flag_id  (feature_flag_id)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => users.id)
#  fk_rails_...  (feature_flag_id => feature_flags.id)
#
FactoryBot.define do
  factory :feature_flag_audit_event do
    association :feature_flag
    association :actor, factory: :user
    action { "updated" }
    details { { "field" => "enabled", "from" => false, "to" => true } }
  end
end
