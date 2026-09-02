require "rails_helper"

RSpec.describe ApprovalRequestPolicy do
  let(:owner) { create(:user) }
  let(:request_record) { create(:approval_request, user: owner) }

  it "allows only the owner to update a request" do
    expect(described_class.new(owner, request_record).update?).to be(true)
    expect(described_class.new(create(:user), request_record).update?).to be(false)
  end

  it "scopes the queue to the authenticated owner" do
    request_record
    create(:approval_request)

    expect(described_class::Scope.new(owner, ApprovalRequest).resolve).to contain_exactly(request_record)
  end
end
