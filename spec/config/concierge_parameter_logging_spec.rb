require "rails_helper"

RSpec.describe "Concierge request privacy" do
  it "filters the entire message payload, including selected context" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    params = { "concierge_message" => { "content" => "Sensitive relationship detail", "private_note_ids" => [ "private-selection" ] } }
    expect(filter.filter(params).inspect).not_to include("Sensitive relationship detail", "private-selection")
  end
end
