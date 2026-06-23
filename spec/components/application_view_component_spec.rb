require "rails_helper"

RSpec.describe ApplicationViewComponent, type: :component do
  it "inherits from ViewComponent::Base" do
    expect(described_class).to be < ViewComponent::Base
  end
end
