require "rails_helper"

# == Schema Information
#
# Table name: personal_touch_items
# Database name: primary
#
#  id                          :uuid             not null, primary key
#  category                    :string           not null
#  completed_at                :datetime
#  details                     :text
#  dismissed_at                :datetime
#  origin                      :string           default("manual"), not null
#  position                    :integer          default(0), not null
#  source_context              :text             default("[]"), not null
#  status                      :string           default("active"), not null
#  title                       :text             not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  personal_touch_checklist_id :uuid             not null
#
# Indexes
#
#  idx_personal_touch_items_checklist_status_position         (personal_touch_checklist_id,status,position)
#  index_personal_touch_items_on_personal_touch_checklist_id  (personal_touch_checklist_id)
#
# Foreign Keys
#
#  fk_rails_...  (personal_touch_checklist_id => personal_touch_checklists.id) ON DELETE => cascade
#
RSpec.describe PersonalTouchItem do
  it "supports every ticket category" do
    expect(described_class::CATEGORIES).to contain_exactly(
      "preference",
      "constraint",
      "message",
      "gift",
      "dietary_need",
      "accessibility_need",
      "logistics",
      "follow_up"
    )
  end

  it "tracks completion, reopening, and dismissal explicitly" do
    item = create(:personal_touch_item)

    item.complete!
    expect(item).to be_completed
    expect(item.completed_at).to be_present

    item.reopen!
    expect(item).to be_active
    expect(item.completed_at).to be_nil

    item.dismiss!
    expect(item).to be_dismissed
    expect(item.dismissed_at).to be_present
  end

  it "keeps repeated transitions idempotent and does not reopen dismissed items" do
    item = create(:personal_touch_item)

    item.complete!
    completed_at = item.reload.completed_at
    item.complete!
    expect(item.reload.completed_at).to eq(completed_at)

    item.dismiss!
    expect { item.reopen! }.to raise_error(ActiveRecord::RecordInvalid)
    expect(item.reload).to be_dismissed
  end

  it "encrypts personal content and provenance at rest" do
    item = create(
      :personal_touch_item,
      title: "Private handwritten note",
      details: "Mention the lake trip",
      source_context: [
        {
          "source_type" => "RelationshipPreference",
          "source_id" => SecureRandom.uuid,
          "source_label" => "Quiet celebrations",
          "certainty" => "confirmed"
        }
      ]
    )

    quoted_id = described_class.connection.quote(item.id)
    raw = described_class.connection.select_one(<<~SQL.squish)
      SELECT title, details, source_context FROM personal_touch_items WHERE id = #{quoted_id}
    SQL

    expect(raw.values.join(" ")).not_to include("Private handwritten note", "lake trip", "Quiet celebrations")
  end

  it "accepts only confirmed or inferred preference certainty" do
    item = build(
      :personal_touch_item,
      source_context: [
        {
          "source_type" => "RelationshipPreference",
          "source_id" => SecureRandom.uuid,
          "source_label" => "Quiet celebrations",
          "certainty" => "unknown"
        }
      ]
    )

    expect(item).not_to be_valid
    expect(item.errors.of_kind?(:source_context, :invalid)).to be(true)
  end

  it "rejects unbounded preference source labels" do
    item = build(
      :personal_touch_item,
      source_context: [
        {
          "source_type" => "RelationshipPreference",
          "source_id" => SecureRandom.uuid,
          "source_label" => "A" * (described_class::MAX_SOURCE_LABEL_LENGTH + 1),
          "certainty" => "inferred"
        }
      ]
    )

    expect(item).not_to be_valid
    expect(item.errors.of_kind?(:source_context, :invalid)).to be(true)
  end

  it "moves within the visible checklist order" do
    checklist = create(:personal_touch_checklist)
    first = create(:personal_touch_item, personal_touch_checklist: checklist, position: 0, title: "First")
    second = create(:personal_touch_item, personal_touch_checklist: checklist, position: 1, title: "Second")
    dismissed = create(:personal_touch_item, personal_touch_checklist: checklist, position: 2, title: "Dismissed", status: "dismissed", dismissed_at: Time.current)

    second.move_up!

    expect(checklist.personal_touch_items.visible.ordered).to eq([ second.reload, first.reload ])
    expect(dismissed.reload.position).to eq(2)
  end

  it "moves up by exactly one visible position" do
    checklist = create(:personal_touch_checklist)
    first = create(:personal_touch_item, personal_touch_checklist: checklist, position: 0, title: "First")
    second = create(:personal_touch_item, personal_touch_checklist: checklist, position: 1, title: "Second")
    third = create(:personal_touch_item, personal_touch_checklist: checklist, position: 2, title: "Third")

    third.move_up!

    expect(checklist.personal_touch_items.visible.ordered).to eq([ first.reload, third.reload, second.reload ])
  end
end
