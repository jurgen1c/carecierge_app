require "rails_helper"

RSpec.describe "Vault MFA parameter filtering" do
  it "filters enrollment and verification credentials without hiding unrelated fields" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    result = filter.filter("vault_mfa" => { "password" => "private", "code" => "123456" },
      "privacy_vault_unlock" => { "password" => "private", "code" => "123456" }, "page" => "2")
    expect(result).to eq("vault_mfa" => "[FILTERED]",
      "privacy_vault_unlock" => { "password" => "[FILTERED]", "code" => "[FILTERED]" }, "page" => "2")
  end
end
