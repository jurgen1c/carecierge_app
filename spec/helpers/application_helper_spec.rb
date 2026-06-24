require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  it "is available to views" do
    expect(helper).to be_a(described_class)
  end

  it "renders component names through the component helper" do
    stub_const("ExampleComponent", Class.new(ViewComponent::Base) do
      def initialize(title:)
        @title = title
      end

      def call
        helpers.tag.span(@title)
      end
    end)

    expect(helper.component("example", title: "Hello")).to include("Hello")
  end
end
