require "rails_helper"

RSpec.describe ApplicationMailer, type: :mailer do
  it "uses the default mailer layout and sender" do
    expect(described_class._layout).to eq("mailer")
    expect(described_class.default[:from].call).to eq(Rails.application.config.x.mail_from)
  end
end
