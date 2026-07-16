# == Schema Information
#
# Table name: privacy_vault_items
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  payload                 :text             not null
#  protectable_type        :string           not null
#  protected_at            :datetime         not null
#  suggestion_usage        :string           default("excluded"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  protectable_id          :uuid             not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_protected_at_06b534e13e  (relationship_profile_id,protected_at)
#  index_privacy_vault_items_on_protectable                (protectable_type,protectable_id) UNIQUE
#  index_privacy_vault_items_on_relationship_profile_id    (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe PrivacyVaultItem, type: :model do
  it "encrypts protected payloads before they reach the database" do
    item = create(
      :privacy_vault_item,
      payload: { "title" => "Private anniversary plan", "body" => "Book the quiet table." }
    )

    ciphertext = item.read_attribute_before_type_cast(:payload)

    expect(ciphertext).not_to include("Private anniversary plan")
    expect(item.reload.payload).to include("title" => "Private anniversary plan")
  end

  it "excludes protected content from suggestion use by default" do
    item = build(:privacy_vault_item)

    expect(item.suggestion_usage).to eq("excluded")
    expect(item).not_to be_suggestion_allowed
  end

  it "rejects unsupported suggestion preferences and protectable types" do
    item = build(:privacy_vault_item, suggestion_usage: "always_share")
    item.protectable_type = "Commitment"

    expect(item).not_to be_valid
    expect(item.errors[:suggestion_usage]).to be_present
    expect(item.errors[:protectable_type]).to be_present
  end

  it "requires an encrypted display title and body" do
    item = build(:privacy_vault_item, payload: { "title" => "Private memory" })

    expect(item).not_to be_valid
    expect(item.errors[:payload]).to be_present
  end

  it "uses the encrypted note title key for the item type badge" do
    profile = create(:relationship_profile)
    note = create(:relationship_note, relationship_profile: profile, category: "General", body: "Shared context")
    item = build(
      :privacy_vault_item,
      relationship_profile: profile,
      protectable: note,
      payload: { "title_key" => "general_note", "category" => "General", "body" => "Shared context" }
    )

    expect(item.type_key).to eq("general_note")
  end

  it "requires the protected record to belong to the same relationship profile" do
    item = build(
      :privacy_vault_item,
      relationship_profile: create(:relationship_profile),
      protectable: create(:memory_record)
    )

    expect(item).not_to be_valid
    expect(item.errors[:protectable]).to be_present
  end
end
