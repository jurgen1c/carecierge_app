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
class VendorOption < ApplicationRecord
  DECISIONS = %w[considering rejected selected].freeze
  MAX_NOTES_LENGTH = 2_000
  MAX_CONSTRAINTS_LENGTH = 2_000
  MAX_NEXT_ACTION_LENGTH = 500

  belongs_to :vendor_shortlist
  belongs_to :vendor

  encrypts :notes
  encrypts :constraints
  encrypts :next_action

  before_validation :normalize_fields

  validates :vendor_id, uniqueness: { scope: :vendor_shortlist_id }
  validates :decision, inclusion: { in: DECISIONS }
  validates :notes, length: { maximum: MAX_NOTES_LENGTH }, allow_blank: true
  validates :constraints, length: { maximum: MAX_CONSTRAINTS_LENGTH }, allow_blank: true
  validates :next_action, length: { maximum: MAX_NEXT_ACTION_LENGTH }, allow_blank: true
  validate :vendor_belongs_to_shortlist_owner
  validate :shortlist_is_mutable, on: :create

  scope :ordered, -> { order(favorite: :desc, created_at: :asc, id: :asc) }
  scope :selected, -> { where(decision: "selected") }

  DECISIONS.each { |value| define_method("#{value}?") { decision == value } }

  def update_details!(attributes, expected_lock_version:)
    mutate do |option|
      unless option.lock_version == expected_lock_version
        raise ActiveRecord::StaleObjectError.new(option, "update")
      end

      option.update!(attributes.slice(:notes, :constraints, :next_action))
    end
  end

  def toggle_favorite!
    mutate { |option| option.update!(favorite: !option.favorite?) }
  end

  def select!
    mutate do |option|
      option.vendor_shortlist.vendor_options.selected.where.not(id: option.id)
        .lock.order(:id).each do |selected_option|
          selected_option.update!(decision: "considering", selected_at: nil)
        end
      option.update!(decision: "selected", selected_at: Time.current, rejected_at: nil)
    end
  end

  def reject!
    mutate { |option| option.update!(decision: "rejected", rejected_at: Time.current, selected_at: nil) }
  end

  def restore!
    mutate { |option| option.update!(decision: "considering", rejected_at: nil, selected_at: nil) }
  end

  def remove!
    vendor_shortlist.with_option_removal_lock do
      vendor_shortlist.vendor_options.lock.find(id).destroy!
    end
  end

  private

  def mutate
    vendor_shortlist.with_mutation_lock do
      yield vendor_shortlist.vendor_options.lock.find(id)
    end
  end

  def normalize_fields
    self.notes = notes.to_s.strip.presence
    self.constraints = constraints.to_s.strip.presence
    self.next_action = next_action.to_s.squish.presence
  end

  def vendor_belongs_to_shortlist_owner
    return if vendor.blank? || vendor_shortlist.blank? || vendor.user_id == vendor_shortlist.user_id

    errors.add(:vendor, :different_owner)
  end

  def shortlist_is_mutable
    errors.add(:vendor_shortlist, :inactive) unless vendor_shortlist&.mutable?
  end
end
