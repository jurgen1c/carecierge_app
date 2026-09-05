require 'rails_helper'

RSpec.describe Messaging::OauthState do
  it 'binds single-use state to the owner and session and expires it' do
    user = create(:user)
    session = {}
    Timecop.freeze do
      state = described_class.issue(user:, session:)
      expect(described_class.verify(state:, user:, session: {})).to be(false)
      expect(described_class.verify(state:, user: create(:user), session: session.dup)).to be(false)
      expect(described_class.verify(state:, user:, session:)).to eq(0)
      expect(described_class.verify(state:, user:, session:)).to be(false)
      state = described_class.issue(user:, session:)
      Timecop.travel(11.minutes.from_now) { expect(described_class.verify(state:, user:, session:)).to be(false) }
    end
  end
end
