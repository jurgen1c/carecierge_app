require "rails_helper"

RSpec.describe BookingPolicy, type: :policy do
  subject(:policy) { described_class.new(user, booking) }

  let(:booking) { create(:booking) }

  context "with the owner" do
    let(:user) { booking.user }

    it "permits owner actions" do
      expect(%i[index create update destroy]).to all(satisfy { |action| policy.public_send("#{action}?") })
    end
  end

  context "with another user" do
    let(:user) { create(:user) }

    it "forbids foreign actions" do
      expect(%i[index create update destroy]).to all(satisfy { |action| !policy.public_send("#{action}?") })
    end
  end

  it "scopes bookings to their owner" do
    owned = create(:booking)
    create(:booking)

    expect(described_class::Scope.new(owned.user, Booking).resolve).to contain_exactly(owned)
  end
end
