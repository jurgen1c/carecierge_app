require "rails_helper"
require Rails.root.join("db/migrate/20260905235653_create_vault_mfa_credentials")

RSpec.describe CreateVaultMfaCredentials do
  it "refuses rollback while authenticator protection is enabled" do
    create(:vault_mfa_credential)
    expect { described_class.new.down }.to raise_error(ActiveRecord::IrreversibleMigration)
    expect(VaultMfaCredential.count).to eq(1)
  end
end
