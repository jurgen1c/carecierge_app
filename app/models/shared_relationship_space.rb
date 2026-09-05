class SharedRelationshipSpace < ApplicationRecord
  belongs_to :owner, class_name: "User"
  belongs_to :partner, class_name: "User", optional: true
  # Delete children before their plans so nullification cannot stale loaded revisions.
  has_many :shared_items, -> { order(:parent_id, :id) }, dependent: :destroy

  has_many :family_memberships, dependent: :destroy

  encrypts :title
  encrypts :invited_email, deterministic: true
  normalizes :invited_email, with: ->(value) { value.to_s.strip.downcase }
  normalizes :title, with: ->(value) { value.to_s.strip }

  validates :title, presence: true, length: { maximum: 120 }
  validates :mode, inclusion: { in: %w[couple family] }
  validates :invited_email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }, unless: :family?
  validates :invitation_expires_at, presence: true, unless: :family?
  validate :two_distinct_people

  scope :participating, ->(user) {
    where(owner_id: user.id).or(where(partner_id: user.id)).or(where(id: FamilyMembership.where(user_id: user.id).select(:shared_relationship_space_id)))
  }
  scope :active, -> { where(mode: "family").or(where.not(accepted_at: nil)) }
  scope :invitations_for, ->(user) {
    where(mode: "couple", invited_email: user.email.downcase, partner_id: nil).where("invitation_expires_at > ?", Time.current)
  }

  def family? = mode == "family"
  def active? = family? || (accepted_at.present? && partner_id.present?)
  def participant?(user)
    user.present? && ([ owner_id, partner_id ].compact.include?(user.id) ||
      (family? && family_memberships.exists?(user_id: user.id)))
  end
  def can_accept?(user)
    !family? && user.present? && user.confirmed? && user.id != owner_id && !active? &&
      invitation_expires_at > Time.current && invited_email == user.email.downcase
  end

  def accept!(user)
    user.with_lock("FOR NO KEY UPDATE") do
      with_lock do
        raise ActiveRecord::RecordNotFound unless can_accept?(user)
        update!(partner: user, accepted_at: Time.current)
      end
    end
  end

  def destroy
    with_lock { super }
  end

  def end_sharing!(user)
    user.with_lock("FOR NO KEY UPDATE") do
      with_lock do
        raise ActiveRecord::RecordNotFound unless family? ? owner_id == user.id : participant?(user) || can_accept?(user)
        destroy!
      end
    end
  end

  private

  def two_distinct_people
    errors.add(:invited_email, :invalid) if owner && invited_email == owner.email.downcase
    errors.add(:partner, :invalid) if partner_id.present? && partner_id == owner_id
  end
end
