FactoryBot.define do
  factory :shared_relationship_space do
    association :owner, factory: :user
    association :partner, factory: :user
    title { "Our shared plans" }
    invited_email { partner.email }
    invitation_expires_at { 7.days.from_now }
    accepted_at { Time.current }
  end

  factory :shared_item do
    shared_relationship_space
    creator { shared_relationship_space.owner }
    title { "A shared plan" }
    kind { "plan" }
    editing { "participants" }
  end
end
