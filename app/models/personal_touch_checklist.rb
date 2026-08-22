# == Schema Information
#
# Table name: personal_touch_checklists
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  event_plan_id           :uuid
#  important_date_id       :uuid
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_personal_touch_checklists_unique_event_plan             (event_plan_id) UNIQUE WHERE (event_plan_id IS NOT NULL)
#  idx_personal_touch_checklists_unique_important_date         (important_date_id) UNIQUE WHERE (important_date_id IS NOT NULL)
#  index_personal_touch_checklists_on_relationship_profile_id  (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (important_date_id => important_dates.id) ON DELETE => cascade
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
class PersonalTouchChecklist < ApplicationRecord
  belongs_to :relationship_profile
  belongs_to :event_plan, optional: true
  belongs_to :important_date, optional: true

  has_many :personal_touch_items, -> { order(:position, :created_at, :id) }, dependent: :destroy
  has_many :visible_personal_touch_items,
    -> { visible.ordered },
    class_name: "PersonalTouchItem"

  validates :event_plan_id, uniqueness: true, allow_nil: true
  validates :important_date_id, uniqueness: true, allow_nil: true
  validate :exactly_one_moment
  validate :moment_matches_relationship_profile

  scope :for_active_relationships, -> { joins(:relationship_profile).where(relationship_profiles: { discarded_at: nil }) }

  def moment
    event_plan || important_date
  end

  def progress
    visible = visible_personal_touch_items.to_a
    completed = visible.count(&:completed?)

    { completed:, total: visible.length }
  end

  def with_mutation_lock
    relationship_profile.user.with_lock do
      relationship_profile.with_lock do
        moment.with_lock do
          with_lock do
            reload
            raise ActiveRecord::RecordNotFound if relationship_profile.discarded?
            raise ActiveRecord::RecordNotFound if moment.respond_to?(:archived?) && moment.archived?

            yield
          end
        end
      end
    end
  end

  private

  def exactly_one_moment
    return if [ event_plan, important_date ].compact.one?

    errors.add(:base, :exactly_one_moment)
  end

  def moment_matches_relationship_profile
    return if moment.nil? || moment.relationship_profile_id == relationship_profile_id

    errors.add(:base, :moment_must_match_relationship_profile)
  end
end
