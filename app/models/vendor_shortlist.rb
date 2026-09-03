# == Schema Information
#
# Table name: vendor_shortlists
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  lock_version            :integer          default(0), not null
#  title                   :text             not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  event_plan_id           :uuid
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_vendor_shortlists_on_event_plan_id            (event_plan_id)
#  index_vendor_shortlists_on_profile_and_created_at   (relationship_profile_id,created_at)
#  index_vendor_shortlists_on_relationship_profile_id  (relationship_profile_id)
#  index_vendor_shortlists_on_user_id                  (user_id)
#  index_vendor_shortlists_on_user_id_and_created_at   (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class VendorShortlist < ApplicationRecord
  MAX_TITLE_LENGTH = 200
  MAX_OPTIONS = 5

  belongs_to :user
  belongs_to :relationship_profile
  belongs_to :event_plan, optional: true
  has_many :vendor_options, -> { ordered }, dependent: :destroy
  has_many :vendors, through: :vendor_options

  encrypts :title

  before_validation :assign_relationship_from_event_plan
  before_validation :normalize_title

  validates :title, presence: true, length: { maximum: MAX_TITLE_LENGTH }
  validate :relationship_profile_belongs_to_user
  validate :event_plan_matches_context
  validate :context_is_active, on: :create

  scope :for_active_relationships, -> { joins(:relationship_profile).merge(RelationshipProfile.active) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def mutable?
    relationship_profile.kept? && (event_plan.nil? || event_plan.active?)
  end

  def selected_option
    vendor_options.find(&:selected?)
  end

  def add_vendor!(vendor)
    with_mutation_lock do
      vendor = user.vendors.find(vendor.id)
      if vendor_options.count >= MAX_OPTIONS
        errors.add(:vendor_options, :too_many, count: MAX_OPTIONS)
        raise ActiveRecord::RecordInvalid, self
      end

      vendor_options.create!(vendor:)
    end
  end

  def with_mutation_lock(&block)
    with_context_lock(require_mutable: true, &block)
  end

  def with_option_removal_lock(&block)
    with_context_lock(require_mutable: false, &block)
  end

  private

  def with_context_lock(require_mutable:, &block)
    user.with_lock("FOR NO KEY UPDATE") do
      relationship_profile.with_lock do
        raise ActiveRecord::RecordNotFound if require_mutable && !relationship_profile.kept?

        if event_plan
          event_plan.with_lock do
            lock_and_yield(require_mutable:, &block)
          end
        else
          lock_and_yield(require_mutable:, &block)
        end
      end
    end
  end

  def lock_and_yield(require_mutable:)
    with_lock do
      reload
      raise ActiveRecord::RecordNotFound if require_mutable && !mutable?

      yield
    end
  end

  def assign_relationship_from_event_plan
    self.relationship_profile = event_plan.relationship_profile if event_plan
  end

  def normalize_title
    self.title = title.to_s.squish
  end

  def relationship_profile_belongs_to_user
    return if user.blank? || relationship_profile.blank? || relationship_profile.user_id == user_id

    errors.add(:relationship_profile, :owner_mismatch)
  end

  def event_plan_matches_context
    return if event_plan.blank?
    return if event_plan.user_id == user_id && event_plan.relationship_profile_id == relationship_profile_id

    errors.add(:event_plan, :context_mismatch)
  end

  def context_is_active
    errors.add(:relationship_profile, :inactive) unless relationship_profile&.kept?
    errors.add(:event_plan, :inactive) if event_plan && !event_plan.active?
  end
end
