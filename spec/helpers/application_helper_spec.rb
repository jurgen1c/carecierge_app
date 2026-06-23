require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  it "is available to views" do
    expect(helper).to be_a(described_class)
  end
end
