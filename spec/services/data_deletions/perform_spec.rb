require "rails_helper"

RSpec.describe DataDeletions::Perform do
  it "uses the owner lock strength that remains compatible with foreign-key checks" do
    user = create(:user)
    expect(user).to receive(:with_lock).with("FOR NO KEY UPDATE").and_call_original

    described_class.call(user:, request_kind: "ai_generated") { nil }

    expect(DeletionRequest.last).to have_attributes(status: "completed", user:)
  end

  it "keeps an exclusive owner lock for whole-account deletion" do
    user = create(:user)
    expect(user).to receive(:with_lock).with(no_args).and_call_original

    described_class.call(user:, request_kind: "account") { nil }

    expect(DeletionRequest.last).to have_attributes(status: "completed", user:)
  end
end
