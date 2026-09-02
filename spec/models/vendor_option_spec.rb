require "rails_helper"

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
RSpec.describe VendorOption, type: :model do
  it "keeps bounded comparison notes and valid decision state" do
    option = build(
      :vendor_option,
      notes: "  Strong reviews from our own research.  ",
      constraints: "  Outdoor service only.  ",
      next_action: "  Confirm the rain plan.  "
    )

    expect(option).to be_valid
    expect(option).to have_attributes(
      notes: "Strong reviews from our own research.",
      constraints: "Outdoor service only.",
      next_action: "Confirm the rain plan.",
      decision: "considering"
    )
  end

  it "rejects vendors owned by someone else and duplicate shortlist entries" do
    shortlist = create(:vendor_shortlist)
    vendor = create(:vendor, user: shortlist.user)
    create(:vendor_option, vendor:, vendor_shortlist: shortlist)

    duplicate = build(:vendor_option, vendor:, vendor_shortlist: shortlist)
    foreign = build(:vendor_option, vendor: create(:vendor), vendor_shortlist: shortlist)

    expect(duplicate).not_to be_valid
    expect(foreign).not_to be_valid
    expect(foreign.errors).to include(:vendor)
  end

  it "encrypts private notes, constraints, and next actions at rest" do
    option = create(
      :vendor_option,
      notes: "Private family preference",
      constraints: "Private dietary constraint",
      next_action: "Ask Maya about the menu"
    )
    quoted_id = described_class.connection.quote(option.id)
    raw = described_class.connection.select_one(<<~SQL.squish)
      SELECT notes, constraints, next_action FROM vendor_options WHERE id = #{quoted_id}
    SQL

    expect(raw.values.join(" ")).not_to include("Private family preference", "Private dietary constraint", "Ask Maya")
  end

  it "supports favorites independently from reject and select decisions" do
    shortlist = create(:vendor_shortlist)
    first = create(:vendor_option, vendor_shortlist: shortlist, vendor: create(:vendor, user: shortlist.user))
    second = create(:vendor_option, vendor_shortlist: shortlist, vendor: create(:vendor, user: shortlist.user))

    first.toggle_favorite!
    first.select!
    second.select!

    expect(first.reload).to have_attributes(favorite: true, decision: "considering")
    expect(second.reload).to have_attributes(decision: "selected")

    second.reject!
    expect(second.reload).to have_attributes(decision: "rejected")

    second.restore!
    expect(second.reload).to have_attributes(decision: "considering")
  end

  it "refuses mutations after its event plan is completed" do
    option = create(:vendor_option)
    option.vendor_shortlist.event_plan.complete!

    expect do
      option.update_details!({ notes: "Changed" }, expected_lock_version: option.lock_version)
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(option.reload.notes).not_to eq("Changed")
  end
end
