require "rails_helper"

RSpec.describe CalendarConnections::OauthState do
  it "round trips a short-lived owner-bound nonce and consumes it once" do
    user = create(:user)
    session = {}

    state = described_class.issue(user:, session:)

    expect(described_class.verify(state:, user:, session:)).to eq(0)
    expect(session).not_to have_key(:calendar_oauth_nonce)
    expect(described_class.verify(state:, user:, session:)).to be(false)
  end

  it "carries the connection generation that existed when authorization began" do
    user = create(:user, calendar_connection_generation: 3)
    session = {}

    state = described_class.issue(user:, session:)
    user.increment!(:calendar_connection_generation)

    expect(described_class.verify(state:, user:, session:)).to eq(3)
  end

  it "fails closed for another owner or a malformed state" do
    user = create(:user)
    session = {}
    state = described_class.issue(user:, session:)

    expect(described_class.verify(state:, user: create(:user), session:)).to be(false)
    expect(described_class.verify(state: "bad-state", user:, session:)).to be(false)
  end
end
