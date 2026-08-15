require "rails_helper"

# == Schema Information
#
# Table name: feed_item_states
# Database name: primary
#
#  id            :uuid             not null, primary key
#  dismissed_at  :datetime
#  item_key      :string           not null
#  snoozed_until :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :uuid             not null
#
# Indexes
#
#  index_feed_item_states_on_user_id                    (user_id)
#  index_feed_item_states_on_user_id_and_item_key       (user_id,item_key) UNIQUE
#  index_feed_item_states_on_user_id_and_snoozed_until  (user_id,snoozed_until) WHERE (snoozed_until IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
RSpec.describe FeedItemState do
  it "requires an owner, a bounded item key, and an active feed state" do
    state = described_class.new(item_key: "", dismissed_at: nil, snoozed_until: nil)

    expect(state).not_to be_valid
    expect(state.errors).to include(:user, :item_key, :base)
  end

  it "keeps one state per item and user while allowing another owner to use the same key" do
    user = create(:user)
    create(:feed_item_state, user:, item_key: "reminder:shared")

    expect(build(:feed_item_state, user:, item_key: "reminder:shared")).not_to be_valid
    expect(build(:feed_item_state, item_key: "reminder:shared")).to be_valid
  end

  it "dismisses permanently and snoozes only until the requested future time" do
    now = Time.zone.local(2026, 8, 14, 9)
    state = build(:feed_item_state, dismissed_at: nil)

    Timecop.freeze(now) do
      state.snooze!(until_time: now + 1.day)
      expect(state).to be_hidden(at: now)
      expect(state).not_to be_hidden(at: now + 1.day)

      state.dismiss!
      expect(state).to be_hidden(at: now + 1.year)
      expect(state.snoozed_until).to be_nil
    end
  end

  it "rejects a snooze that is not in the future" do
    now = Time.zone.local(2026, 8, 14, 9)

    Timecop.freeze(now) do
      expect { build(:feed_item_state).snooze!(until_time: now) }.to raise_error(ArgumentError)
    end
  end

  it "atomically reuses the owner and item row when visibility mutations repeat" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)

    Timecop.freeze(now) do
      expect do
        described_class.dismiss_for!(user:, item_key: "reminder:shared", at: now)
      end.to change(described_class, :count).by(1)

      expect do
        described_class.snooze_for!(user:, item_key: "reminder:shared", until_time: now + 1.day)
      end.not_to change(described_class, :count)
    end

    expect(user.feed_item_states.find_by!(item_key: "reminder:shared")).to have_attributes(
      dismissed_at: nil,
      snoozed_until: now + 1.day
    )
  end

  it "removes obsolete state when a feed source or relationship is permanently deleted" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    sources = {
      "reminder" => create(:reminder, user:, relationship_profile: profile),
      "commitment" => create(:commitment, relationship_profile: profile),
      "important_date" => create(:important_date, relationship_profile: profile),
      "gift" => create(:gift, relationship_profile: profile),
      "message_draft" => create(:message_draft, user:, relationship_profile: profile),
      "relationship_goal" => create(:desire, relationship_profile: profile)
    }
    sources.each do |prefix, source|
      create(:feed_item_state, user:, item_key: "#{prefix}:#{source.id}")
    end

    sources.each_value(&:destroy!)

    expect(user.feed_item_states.reload).to be_empty

    suggestion_state = create(
      :feed_item_state,
      user:,
      item_key: "suggestion:#{profile.id}:stable-fingerprint"
    )
    profile.destroy!

    expect(described_class.exists?(suggestion_state.id)).to be(false)
  end

  it "cleans feed state only after the source row has been deleted" do
    user = create(:user)
    source = create(:reminder, user:)
    create(:feed_item_state, user:, item_key: "reminder:#{source.id}")

    allow(described_class).to receive(:delete_for_source!).and_wrap_original do |original, destroyed_source|
      expect(destroyed_source).to be_destroyed
      expect(Reminder.exists?(destroyed_source.id)).to be(false)
      original.call(destroyed_source)
    end

    source.destroy!

    expect(user.feed_item_states.reload).to be_empty
  end

  it "removes suggestion state when any source that contributes its fingerprint is deleted" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    sources = {
      create(:relationship_preference, relationship_profile: profile) => %w[message],
      create(:memory_record, relationship_profile: profile) => %w[message],
      create(:social_context_note, relationship_profile: profile) => %w[gift message conversation_topic social_reminder],
      create(:contact_cadence, relationship_profile: profile) => %w[check_in],
      create(:important_date, relationship_profile: profile) => %w[event],
      create(:desire, relationship_profile: profile) => %w[gift plan spontaneous],
      create(:mood_note, relationship_profile: profile) => %w[repair_focused],
      create(:commitment, relationship_profile: profile) => %w[professional_follow_up]
    }
    sources.each do |source, suggestion_types|
      suggestion_types.each do |type|
        fingerprint = Digest::SHA256.hexdigest([ "v1", profile.id, type, source.class.base_class.name, source.id ].join(":"))
        create(:feed_item_state, user:, item_key: "suggestion:#{profile.id}:#{fingerprint}")
      end
    end

    sources.each_key(&:destroy!)

    expect(user.feed_item_states.reload).to be_empty
  end
end
