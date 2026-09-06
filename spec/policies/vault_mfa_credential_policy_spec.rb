require "rails_helper"

RSpec.describe VaultMfaCredentialPolicy do
  it "permits only the owner, including for admin users" do
    credential = create(:vault_mfa_credential)
    expect(described_class.new(credential.user, credential)).to be_update
    expect(described_class.new(create(:user, admin: true), credential)).not_to be_update
    expect(described_class.new(nil, credential)).not_to be_update
  end
end
