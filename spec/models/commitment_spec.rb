# == Schema Information
#
# Table name: commitments
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  completed_at            :datetime
#  due_on                  :date
#  notes                   :text
#  status                  :string           default("open"), not null
#  title                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_status_due_on_109b7b7dd5  (relationship_profile_id,status,due_on)
#  index_commitments_on_open_due_on                         (status,due_on) WHERE (((status)::text = 'open'::text) AND (due_on IS NOT NULL))
#  index_commitments_on_relationship_profile_id             (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe Commitment, type: :model do
  subject(:commitment) { build(:commitment) }

  it { is_expected.to belong_to(:relationship_profile) }
  it { is_expected.to have_many(:reminders).dependent(:destroy) }
  it { is_expected.to have_one(:timeline_entry).dependent(:destroy) }
  it { is_expected.to have_db_column(:title).of_type(:string).with_options(null: false) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_inclusion_of(:status).in_array(%w[open completed canceled]) }

  it "normalizes user-authored text" do
    commitment.title = "  Send   the article  "
    commitment.notes = "  Include the summary.  \n"

    commitment.validate

    expect(commitment).to have_attributes(title: "Send the article", notes: "Include the summary.")
  end

  it "derives overdue state only for open commitments past their due date" do
    expect(build(:commitment, status: "open", due_on: Date.new(2026, 7, 13))).to be_overdue(Date.new(2026, 7, 14))
    expect(build(:commitment, status: "open", due_on: Date.new(2026, 7, 14))).not_to be_overdue(Date.new(2026, 7, 14))
    expect(build(:commitment, status: "completed", due_on: Date.new(2026, 7, 13))).not_to be_overdue(Date.new(2026, 7, 14))
    expect(build(:commitment, status: "open", due_on: nil)).not_to be_overdue(Date.new(2026, 7, 14))
  end

  it "completes and reopens through domain transitions" do
    commitment = create(:commitment, status: "open")
    completed_at = Time.zone.local(2026, 7, 14, 10, 30)

    Timecop.freeze(completed_at) { commitment.complete! }
    expect(commitment).to have_attributes(status: "completed", completed_at: completed_at)

    commitment.reopen!
    expect(commitment).to have_attributes(status: "open", completed_at: nil)
  end

  it "cancels without retaining a completion time" do
    commitment = create(:commitment, status: "open", completed_at: 1.day.ago)

    commitment.cancel!

    expect(commitment).to have_attributes(status: "canceled", completed_at: nil)
  end

  it "retires active reminders when completed without reactivating them on reopen" do
    commitment = create(:commitment)
    reminder = create(:reminder, user: commitment.relationship_profile.user, relationship_profile: commitment.relationship_profile, commitment:)
    completed_at = Time.zone.parse("2026-07-14 09:30")

    commitment.complete!(at: completed_at)

    expect(reminder.reload).to have_attributes(status: "completed", completed_at:, next_delivery_at: nil, snoozed_until: nil)

    commitment.reopen!

    expect(reminder.reload).to be_completed
  end

  it "retires active reminders when canceled" do
    commitment = create(:commitment)
    reminder = create(:reminder, user: commitment.relationship_profile.user, relationship_profile: commitment.relationship_profile, commitment:)
    canceled_at = Time.zone.parse("2026-07-14 10:00")

    commitment.cancel!(at: canceled_at)

    expect(reminder.reload).to have_attributes(status: "completed", completed_at: canceled_at, next_delivery_at: nil, snoozed_until: nil)
  end

  it "rejects invalid status transitions" do
    open_commitment = create(:commitment, status: "open")
    canceled_commitment = create(:commitment, status: "canceled")

    expect { open_commitment.reopen! }.to raise_error(ActiveRecord::RecordInvalid)
    expect { canceled_commitment.complete! }.to raise_error(ActiveRecord::RecordInvalid)
    expect { canceled_commitment.cancel! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  describe ".overdue" do
    it "returns open past-due commitments in due-date order" do
      due_later = create(:commitment, due_on: Date.new(2026, 7, 12))
      due_first = create(:commitment, due_on: Date.new(2026, 7, 10))
      create(:commitment, due_on: Date.new(2026, 7, 14))
      create(:commitment, due_on: Date.new(2026, 7, 9), status: "completed")

      expect(described_class.overdue(Date.new(2026, 7, 14))).to eq([ due_first, due_later ])
    end
  end
end
