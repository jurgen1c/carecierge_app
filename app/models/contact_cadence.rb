# == Schema Information
#
# Table name: contact_cadences
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  interval_days           :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_contact_cadences_on_relationship_profile_id  (relationship_profile_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
class ContactCadence < ApplicationRecord
  INTERVAL_DAYS = [ 7, 14, 30, 60, 90 ].freeze

  WEEKLY_TYPES = %w[
    RelationshipProfiles::BestFriend RelationshipProfiles::Spouse RelationshipProfiles::Partner
    RelationshipProfiles::Fiance RelationshipProfiles::Fiancee RelationshipProfiles::SignificantOther
    RelationshipProfiles::Mother RelationshipProfiles::Father RelationshipProfiles::Parent
    RelationshipProfiles::Stepparent RelationshipProfiles::Guardian RelationshipProfiles::Child
    RelationshipProfiles::Son RelationshipProfiles::Daughter
  ].freeze
  BIWEEKLY_TYPES = %w[
    RelationshipProfiles::Friend RelationshipProfiles::Family RelationshipProfiles::Sibling
    RelationshipProfiles::Brother RelationshipProfiles::Sister RelationshipProfiles::Grandparent
    RelationshipProfiles::Grandmother RelationshipProfiles::Grandfather RelationshipProfiles::Grandchild
    RelationshipProfiles::Aunt RelationshipProfiles::Uncle RelationshipProfiles::Cousin
    RelationshipProfiles::Niece RelationshipProfiles::Nephew RelationshipProfiles::InLaw
    RelationshipProfiles::Roommate RelationshipProfiles::Housemate
  ].freeze
  MONTHLY_TYPES = %w[
    RelationshipProfiles::ExtendedFamily RelationshipProfiles::Boss RelationshipProfiles::Manager
    RelationshipProfiles::DirectReport RelationshipProfiles::Coworker RelationshipProfiles::Mentor
    RelationshipProfiles::Mentee RelationshipProfiles::Advisor RelationshipProfiles::Colleague
    RelationshipProfiles::BusinessPartner RelationshipProfiles::Client RelationshipProfiles::Customer
    RelationshipProfiles::Neighbor RelationshipProfiles::Classmate RelationshipProfiles::Teacher
    RelationshipProfiles::Student RelationshipProfiles::Coach RelationshipProfiles::Teammate
    RelationshipProfiles::CommunityMember RelationshipProfiles::Caregiver RelationshipProfiles::CareRecipient
    RelationshipProfiles::Doctor RelationshipProfiles::Therapist
  ].freeze

  belongs_to :relationship_profile

  validates :relationship_profile_id, uniqueness: true
  validates :interval_days, inclusion: { in: INTERVAL_DAYS }

  def self.suggested_interval_days_for(relationship_profile)
    case relationship_profile.type
    when *WEEKLY_TYPES then 7
    when *BIWEEKLY_TYPES then 14
    when *MONTHLY_TYPES then 30
    else 90
    end
  end

  def last_interaction_at
    return @last_interaction_at if defined?(@last_interaction_at)

    @last_interaction_at = relationship_profile.interactions.maximum(:occurred_at)
  end

  def next_check_in_at
    @next_check_in_at ||= (last_interaction_at || created_at) + interval_days.days
  end

  def overdue?(as_of: Time.current)
    next_check_in_at < as_of
  end
end
