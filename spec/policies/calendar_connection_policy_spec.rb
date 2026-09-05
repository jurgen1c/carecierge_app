require "rails_helper"

RSpec.describe CalendarConnectionPolicy do
  subject(:policy) { described_class.new(user, record) }

  let(:user) { create(:user) }
  let(:record) { create(:calendar_connection, user:) }

  it "allows an owner to view, update, sync, and disconnect" do
    expect(%i[show update sync destroy]).to all(satisfy { |action| policy.public_send("#{action}?") })
  end

  it "allows an authenticated user to begin a new connection" do
    class_policy = described_class.new(user, CalendarConnection)
    expect(%i[new create callback]).to all(satisfy { |action| class_policy.public_send("#{action}?") })
  end

  it "denies another owner" do
    foreign_policy = described_class.new(create(:user), record)
    expect(%i[show update sync destroy]).to all(satisfy { |action| !foreign_policy.public_send("#{action}?") })
  end
end
