require "rails_helper"

RSpec.describe CalendarSyncs::Sources do
  it "returns only selected eligible records belonging to active owner relationships" do
    connection = create(:calendar_connection, sync_types: CalendarConnection::SYNC_TYPES)
    user = connection.user
    active_profile = create(:relationship_profile, user:)
    archived_profile = create(:relationship_profile, user:)
    active_plan = create(:event_plan, user:, relationship_profile: active_profile)
    archived_profile_plan = create(:event_plan, user:, relationship_profile: archived_profile)
    archived_date = create(:important_date, relationship_profile: archived_profile)
    archived_reminder = create(:reminder, user:, relationship_profile: archived_profile)
    archived_booking = create(:booking, user:, event_plan: archived_profile_plan)
    archived_commitment = create(:commitment, relationship_profile: archived_profile)
    archived_profile.discard!
    eligible = [
      create(:important_date, relationship_profile: active_profile),
      create(:reminder, user:, relationship_profile: active_profile),
      create(:reminder, user:, relationship_profile: nil),
      active_plan,
      create(:booking, user:, event_plan: active_plan),
      create(:commitment, relationship_profile: active_profile)
    ]
    excluded = [
      archived_date,
      archived_reminder,
      archived_profile_plan,
      archived_booking,
      archived_commitment,
      create(:reminder),
      create(:event_plan, user:, relationship_profile: active_profile, starts_on: nil),
      create(:commitment, relationship_profile: active_profile, due_on: nil),
      create(:booking, user:, event_plan: active_plan, status: "completed")
    ]

    result = described_class.for(connection)

    expect(result).to include(*eligible)
    expect(result).not_to include(*excluded)
  end

  it "returns only explicitly selected source types" do
    connection = create(:calendar_connection, sync_types: [ "commitments" ])
    profile = create(:relationship_profile, user: connection.user)
    commitment = create(:commitment, relationship_profile: profile)
    create(:important_date, relationship_profile: profile)

    expect(described_class.for(connection)).to eq([ commitment ])
  end
end
