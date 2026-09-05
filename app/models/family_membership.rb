class FamilyMembership < ApplicationRecord
  RELATIONSHIP_TYPES = %w[parent child sibling grandparent extended_family chosen_family other].freeze
  belongs_to :shared_relationship_space
  belongs_to :user, optional: true
  encrypts :invited_email, deterministic: true
  normalizes :invited_email, with: ->(value) { value.to_s.strip.downcase }
  validates :invited_email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { scope: :shared_relationship_space_id }
  validates :relationship_type, inclusion: { in: RELATIONSHIP_TYPES }
  validates :invitation_expires_at, presence: true
  validate :family_context

  scope :invitations_for, ->(person) { where(user_id: nil, invited_email: person.email.downcase).where("invitation_expires_at > ?", Time.current) }

  def can_accept?(person)
    person&.confirmed? && !user_id && invitation_expires_at > Time.current &&
      invited_email == person.email.downcase && shared_relationship_space.owner_id != person.id
  end

  def accept!(person)
    person.with_lock("FOR NO KEY UPDATE") do
      shared_relationship_space.with_lock do
        reload
        raise ActiveRecord::RecordNotFound unless can_accept?(person)
        update!(user: person, accepted_at: Time.current)
      end
    end
  end

  # This lifecycle also runs during account deletion; serialize with content writes.
  def destroy
    shared_relationship_space.with_lock do
      if user_id
        items = shared_relationship_space.shared_items
        items.where(creator_id: user_id).destroy_all
        items.where(assignee_id: user_id).find_each { |item| item.update!(assignee: nil) }
        SharedReminderSubscription.where(user_id:, shared_item_id: items.select(:id)).destroy_all
        FamilyResponse.where(user_id:, shared_item_id: items.select(:id)).destroy_all
        events = Noticed::Event.where(record_type: "SharedItem", record_id: items.select(:id))
        Noticed::Notification.where(recipient_type: "User", recipient_id: user_id, event_id: events.select(:id)).destroy_all
      end
      super
    end
  end

  private

  def family_context
    space = shared_relationship_space
    errors.add(:base, :invalid) unless space&.family?
    errors.add(:invited_email, :invalid) if space&.owner&.email&.downcase == invited_email
    errors.add(:user, :invalid) if user_id && (space&.owner_id == user_id || !accepted_at)
  end
end
