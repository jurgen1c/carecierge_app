# == Schema Information
#
# Table name: personal_touch_items
# Database name: primary
#
#  id                          :uuid             not null, primary key
#  category                    :string           not null
#  completed_at                :datetime
#  details                     :text
#  dismissed_at                :datetime
#  origin                      :string           default("manual"), not null
#  position                    :integer          default(0), not null
#  source_context              :text             default("[]"), not null
#  status                      :string           default("active"), not null
#  title                       :text             not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  personal_touch_checklist_id :uuid             not null
#
# Indexes
#
#  idx_personal_touch_items_checklist_status_position         (personal_touch_checklist_id,status,position)
#  index_personal_touch_items_on_personal_touch_checklist_id  (personal_touch_checklist_id)
#
# Foreign Keys
#
#  fk_rails_...  (personal_touch_checklist_id => personal_touch_checklists.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :personal_touch_item do
    personal_touch_checklist
    category { "message" }
    title { "Write a short personal note" }
    details { nil }
    origin { "manual" }
    status { "active" }
    sequence(:position)
    source_context { [] }
  end
end
