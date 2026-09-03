# == Schema Information
#
# Table name: vendor_options
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  constraints         :text
#  decision            :string           default("considering"), not null
#  favorite            :boolean          default(FALSE), not null
#  lock_version        :integer          default(0), not null
#  next_action         :text
#  notes               :text
#  rejected_at         :datetime
#  selected_at         :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  vendor_id           :uuid             not null
#  vendor_shortlist_id :uuid             not null
#
# Indexes
#
#  index_vendor_options_on_one_selected_per_shortlist         (vendor_shortlist_id) UNIQUE WHERE ((decision)::text = 'selected'::text)
#  index_vendor_options_on_vendor_id                          (vendor_id)
#  index_vendor_options_on_vendor_shortlist_id                (vendor_shortlist_id)
#  index_vendor_options_on_vendor_shortlist_id_and_vendor_id  (vendor_shortlist_id,vendor_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (vendor_id => vendors.id)
#  fk_rails_...  (vendor_shortlist_id => vendor_shortlists.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :vendor_option do
    association :vendor_shortlist
    vendor { association(:vendor, user: vendor_shortlist.user) }
    notes { "A promising option from our own research." }
    constraints { "Confirm final availability." }
    next_action { "Review the source together." }
  end
end
