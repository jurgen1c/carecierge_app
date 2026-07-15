# == Schema Information
#
# Table name: reminders
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  completed_at            :datetime
#  next_delivery_at        :datetime
#  notes                   :text
#  priority                :string           default("normal"), not null
#  recurrence              :string           default("none"), not null
#  recurrence_anchor_at    :datetime         not null
#  reminder_type           :string           default("custom"), not null
#  scheduled_at            :datetime         not null
#  snoozed_until           :datetime
#  status                  :string           default("active"), not null
#  time_zone               :string           default("UTC"), not null
#  title                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  commitment_id           :uuid
#  important_date_id       :uuid
#  relationship_profile_id :uuid
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_reminders_on_active_next_delivery_at              (next_delivery_at) WHERE (((status)::text = 'active'::text) AND (next_delivery_at IS NOT NULL))
#  index_reminders_on_commitment_id                        (commitment_id)
#  index_reminders_on_important_date_id                    (important_date_id)
#  index_reminders_on_profile_status_and_schedule          (relationship_profile_id,status,scheduled_at)
#  index_reminders_on_relationship_profile_id              (relationship_profile_id)
#  index_reminders_on_user_id                              (user_id)
#  index_reminders_on_user_id_and_status_and_scheduled_at  (user_id,status,scheduled_at)
#
# Foreign Keys
#
#  fk_rails_...  (commitment_id => commitments.id) ON DELETE => cascade
#  fk_rails_...  (important_date_id => important_dates.id) ON DELETE => nullify
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe Reminder, type: :model do
  it "accepts a commitment owned by the same user and relationship" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    commitment = create(:commitment, relationship_profile: profile)

    reminder = build(:reminder, user:, relationship_profile: profile, commitment:)

    expect(reminder).to be_valid
  end

  it "rejects a commitment from another user or relationship" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    other_profile = create(:relationship_profile, user:)
    other_owner_commitment = create(:commitment)
    other_relationship_commitment = create(:commitment, relationship_profile: other_profile)

    reminder = build(:reminder, user:, relationship_profile: profile, commitment: other_owner_commitment)
    I18n.with_locale(:en) do
      expect(reminder).not_to be_valid
      expect(reminder.errors[:commitment]).to include("must belong to you")
    end

    reminder.commitment = other_relationship_commitment
    I18n.with_locale(:es) do
      expect(reminder).not_to be_valid
      expect(reminder.errors[:commitment]).to include("debe pertenecer a la relación seleccionada")
    end
  end

  it "requires a recognized IANA timezone" do
    reminder = build(:reminder, time_zone: "Mars/Olympus_Mons")

    expect(reminder).not_to be_valid
    expect(reminder.errors[:time_zone]).to be_present
  end

  it "uses the application timezone to render a correction form for an invalid timezone" do
    reminder = build(:reminder, scheduled_at: Time.utc(2026, 7, 25, 15), time_zone: "Mars/Olympus_Mons")

    expect { reminder.local_scheduled_at }.not_to raise_error
    expect(reminder.local_scheduled_at).to eq(Time.zone.parse("2026-07-25 15:00"))
  end

  describe "validations" do
    it "requires supported reminder attributes" do
      reminder = build(
        :reminder,
        title: " ",
        reminder_type: "unknown",
        priority: "urgent",
        recurrence: "sometimes",
        status: "paused",
        scheduled_at: nil
      )

      expect(reminder).not_to be_valid
      expect(reminder.errors[:title]).to include("can't be blank")
      expect(reminder.errors[:reminder_type]).to include("is not included in the list")
      expect(reminder.errors[:priority]).to include("is not included in the list")
      expect(reminder.errors[:recurrence]).to include("is not included in the list")
      expect(reminder.errors[:status]).to include("is not included in the list")
      expect(reminder.errors[:scheduled_at]).to include("can't be blank")
    end

    it "rejects relationship and important-date associations outside the owner boundary" do
      owner = create(:user)
      other_profile = create(:relationship_profile)
      other_date = create(:important_date, relationship_profile: other_profile)
      reminder = build(:reminder, user: owner, relationship_profile: other_profile, important_date: other_date)

      expect(reminder).not_to be_valid
      expect(reminder.errors[:relationship_profile]).to include("must belong to you")
      expect(reminder.errors[:important_date]).to include("must belong to you")
    end

    it "requires an important date to match the selected relationship" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      other_profile = create(:relationship_profile, user:)
      important_date = create(:important_date, relationship_profile: other_profile)
      reminder = build(:reminder, user:, relationship_profile: profile, important_date:)

      expect(reminder).not_to be_valid
      expect(reminder.errors[:important_date]).to include("must belong to the selected relationship")
    end

    it "localizes an important-date relationship mismatch" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      important_date = create(:important_date, relationship_profile: create(:relationship_profile, user:))
      reminder = build(:reminder, user:, relationship_profile: profile, important_date:)

      I18n.with_locale(:es) do
        reminder.validate
        expect(reminder.errors.full_messages).to include("Fecha importante debe pertenecer a la relación seleccionada")
      end
    end
  end

  describe "delivery state" do
    it "normalizes its title and initializes the next delivery time" do
      reminder = create(:reminder, title: "  Call Elena  ", next_delivery_at: nil)

      expect(reminder).to have_attributes(title: "Call Elena", next_delivery_at: reminder.scheduled_at)
    end

    it "snoozes an active reminder without changing its recurring schedule" do
      reminder = create(:reminder, scheduled_at: Time.zone.local(2026, 7, 14, 16, 30))
      snoozed_until = Time.zone.local(2026, 7, 14, 18, 0)

      Timecop.freeze(Time.zone.local(2026, 7, 14, 17, 0)) do
        reminder.snooze!(until_time: snoozed_until)
      end

      expect(reminder.reload).to have_attributes(
        scheduled_at: Time.zone.local(2026, 7, 14, 16, 30),
        snoozed_until:,
        next_delivery_at: snoozed_until
      )
      expect(reminder.effective_delivery_at).to eq(snoozed_until)
      expect(reminder).not_to be_overdue(Time.zone.local(2026, 7, 14, 17, 30))
    end

    it "rejects snoozing into the past or snoozing a completed reminder" do
      now = Time.zone.local(2026, 7, 14, 17, 0)

      Timecop.freeze(now) do
        expect { create(:reminder).snooze!(until_time: now - 1.minute) }
          .to raise_error(ArgumentError, "Snooze time must be in the future")
        expect { create(:reminder, status: "completed").snooze!(until_time: now + 1.hour) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    it "completes a one-time reminder" do
      reminder = create(:reminder)

      completed_at = Time.zone.local(2026, 7, 14, 17, 0)
      Timecop.freeze(completed_at) { reminder.complete! }

      expect(reminder.reload).to have_attributes(status: "completed", completed_at:, next_delivery_at: nil)
    end

    it "advances a recurring reminder to its next future occurrence" do
      reminder = create(
        :reminder,
        recurrence: "weekly",
        scheduled_at: Time.zone.local(2026, 7, 1, 9, 0),
        next_delivery_at: nil
      )

      Timecop.freeze(Time.zone.local(2026, 7, 13, 12, 0)) { reminder.complete! }

      expect(reminder.reload).to have_attributes(
        status: "active",
        scheduled_at: Time.zone.local(2026, 7, 15, 9, 0),
        next_delivery_at: Time.zone.local(2026, 7, 15, 9, 0),
        completed_at: nil
      )
    end

    it "preserves a month-end recurrence anchor after shorter months" do
      reminder = create(
        :reminder,
        recurrence: "monthly",
        scheduled_at: Time.zone.local(2026, 1, 31, 9, 0)
      )

      Timecop.freeze(Time.zone.local(2026, 1, 31, 10, 0)) { reminder.complete! }
      expect(reminder.reload.scheduled_at).to eq(Time.zone.local(2026, 2, 28, 9, 0))

      Timecop.freeze(Time.zone.local(2026, 2, 28, 10, 0)) { reminder.complete! }
      expect(reminder.reload.scheduled_at).to eq(Time.zone.local(2026, 3, 31, 9, 0))
    end

    it "returns leap-day yearly reminders to February 29" do
      reminder = create(
        :reminder,
        recurrence: "yearly",
        scheduled_at: Time.zone.local(2024, 2, 29, 9, 0)
      )

      Timecop.freeze(Time.zone.local(2024, 2, 29, 10, 0)) { reminder.complete! }
      expect(reminder.reload.scheduled_at).to eq(Time.zone.local(2025, 2, 28, 9, 0))

      Timecop.freeze(Time.zone.local(2025, 2, 28, 10, 0)) { reminder.complete!(at: Time.zone.local(2028, 2, 28, 10, 0)) }
      expect(reminder.reload.scheduled_at).to eq(Time.zone.local(2028, 2, 29, 9, 0))
    end

    it "preserves the local wall-clock time across daylight-saving changes" do
      new_york = ActiveSupport::TimeZone["America/New_York"]
      reminder = create(
        :reminder,
        recurrence: "weekly",
        time_zone: "America/New_York",
        scheduled_at: new_york.local(2026, 3, 1, 9, 0)
      )

      Timecop.freeze(new_york.local(2026, 3, 1, 10, 0)) { reminder.complete! }

      expect(reminder.reload.scheduled_at).to eq(Time.utc(2026, 3, 8, 13, 0))
      expect(reminder.local_scheduled_at.hour).to eq(9)
    end

    it "advances an upcoming recurring reminder at least once when completed early" do
      reminder = create(
        :reminder,
        recurrence: "weekly",
        scheduled_at: Time.zone.local(2026, 7, 20, 9, 0)
      )

      Timecop.freeze(Time.zone.local(2026, 7, 14, 12, 0)) { reminder.complete! }

      expect(reminder.reload.scheduled_at).to eq(Time.zone.local(2026, 7, 27, 9, 0))
    end

    it "deletes its Noticed events and notifications" do
      reminder = create(:reminder)
      ReminderInAppNotifier.with(record: reminder).deliver(reminder.user)
      event = Noticed::Event.find_by!(record: reminder)

      expect { reminder.destroy! }
        .to change(Noticed::Event.where(id: event.id), :count).from(1).to(0)
        .and change(Noticed::Notification.where(event_id: event.id), :count).from(1).to(0)
    end

    {
      "daily" => Time.zone.local(2026, 7, 15, 9, 0),
      "monthly" => Time.zone.local(2026, 8, 14, 9, 0),
      "yearly" => Time.zone.local(2027, 7, 14, 9, 0)
    }.each do |recurrence, expected_time|
      it "advances a #{recurrence} reminder" do
        reminder = create(
          :reminder,
          recurrence:,
          scheduled_at: Time.zone.local(2026, 7, 14, 9, 0)
        )

        Timecop.freeze(Time.zone.local(2026, 7, 14, 12, 0)) { reminder.complete! }

        expect(reminder.reload.scheduled_at).to eq(expected_time)
      end
    end
  end

  describe ".due" do
    it "returns only active reminders whose next delivery is due" do
      due = create(:reminder, next_delivery_at: Time.zone.local(2026, 7, 14, 8, 0))
      create(:reminder, next_delivery_at: Time.zone.local(2026, 7, 14, 12, 0))
      create(:reminder, status: "completed", completed_at: Time.zone.local(2026, 7, 13, 8, 0), next_delivery_at: nil)

      expect(described_class.due(Time.zone.local(2026, 7, 14, 9, 0))).to contain_exactly(due)
    end
  end

  describe ".by_effective_delivery" do
    it "orders active reminders by snooze time or scheduled time in SQL" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      snoozed = create(
        :reminder,
        user:,
        relationship_profile: profile,
        scheduled_at: 1.day.ago,
        snoozed_until: 2.days.from_now
      )
      upcoming = create(:reminder, user:, relationship_profile: profile, scheduled_at: 1.day.from_now)

      expect(profile.reminders.active.by_effective_delivery).to eq([ upcoming, snoozed ])
    end
  end
end
