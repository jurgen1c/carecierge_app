FactoryBot.define do
  factory :relationship_preference do
    relationship_profile
    key { "Coffee" }
    value { "decaf" }
  end
end
