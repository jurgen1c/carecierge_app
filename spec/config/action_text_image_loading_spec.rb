require "rails_helper"

RSpec.describe "Action Text image loading attributes" do
  it "keeps the lazy-loading sanitizer attributes unique across repeated initialization" do
    original_attributes = ActionText::ContentHelper.allowed_attributes

    load Rails.root.join("config/initializers/action_text_image_loading.rb")

    expect(ActionText::ContentHelper.allowed_attributes.count("loading")).to eq(1)
    expect(ActionText::ContentHelper.allowed_attributes.count("decoding")).to eq(1)
  ensure
    ActionText::ContentHelper.allowed_attributes = original_attributes
  end
end
