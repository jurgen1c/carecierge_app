class SharedRelationshipSpace < ApplicationRecord
  belongs_to :owner, class_name: "User"
  belongs_to :partner, class_name: "User", optional: true
  # Delete children before their plans so nullification cannot stale loaded revisions.
  has_many :shared_items, -> { order(:parent_id, :id) }, dependent: :destroy

  encrypts :title
  encrypts :invited_email, deterministic: true
  normalizes :invited_email, with: ->(value) { value.to_s.strip.downcase }
  normalizes :title, with: ->(value) { value.to_s.strip }

  validates :title, presence: true, length: { maximum: 120 }
  validates :invited_email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :invitation_expires_at, presence: true
  validate :two_distinct_people

  scope :participating, ->(user) { where(owner_id: user.id).or(where(partner_id: user.id)) }
  scope :active, -> { where.not(accepted_at: nil) }
  scope :invitations_for, ->(user) {
    where(invited_email: user.email.downcase, partner_id: nil).where("invitation_expires_at > ?", Time.current)
  }

  def active? = accepted_at.present? && partner_id.present?
  def participant?(user) = user.present? && [ owner_id, partner_id ].compact.include?(user.id)
  def can_accept?(user)
    user.present? && user.confirmed? && user.id != owner_id && !active? &&
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
        raise ActiveRecord::RecordNotFound unless participant?(user) || can_accept?(user)
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
