# == Schema Information
#
# Table name: vendors
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  availability        :text
#  category            :string           not null
#  fit_notes           :text
#  location            :string
#  maximum_price_cents :integer
#  minimum_price_cents :integer
#  name                :string           not null
#  occasion_types      :jsonb            not null
#  preference_tags     :jsonb            not null
#  source_kind         :string           default("manual"), not null
#  source_name         :string
#  source_url          :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  user_id             :uuid             not null
#
# Indexes
#
#  index_vendors_on_occasion_types        (occasion_types) USING gin
#  index_vendors_on_preference_tags       (preference_tags) USING gin
#  index_vendors_on_user_and_lower_name   (user_id, lower((name)::text))
#  index_vendors_on_user_id               (user_id)
#  index_vendors_on_user_id_and_category  (user_id,category)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :vendor do
    association :user
    name { "Bloom & Stem" }
    category { "florist" }
    location { "San Jose, Costa Rica" }
    minimum_price_cents { 15_000 }
    maximum_price_cents { 45_000 }
    availability { "Available Saturday afternoons" }
    occasion_types { [ "birthday" ] }
    preference_tags { [ "local", "seasonal" ] }
    fit_notes { "Seasonal arrangements fit a relaxed birthday dinner." }
    source_kind { "manual" }
    source_name { "Personal research" }
  end
end
