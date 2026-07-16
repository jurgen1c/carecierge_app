require "rails_helper"
require Rails.root.join("db/migrate/20260716125513_create_privacy_vault_items")
require Rails.root.join("db/migrate/20260716125514_create_vault_access_events")
require Rails.root.join("db/migrate/20260716125515_add_privacy_vault_lease_version_to_users")

RSpec.describe CreatePrivacyVaultItems do
  it "refuses to drop encrypted payloads while protected items exist" do
    migration = described_class.new
    allow(migration).to receive(:table_exists?).with(:privacy_vault_items).and_return(true)
    allow(migration).to receive(:select_value).and_return(1)
    allow(migration).to receive(:drop_table)

    expect { migration.down }.to raise_error(ActiveRecord::IrreversibleMigration, /protected items exist/i)
    expect(migration).not_to have_received(:drop_table)
  end
end

RSpec.describe CreateVaultAccessEvents do
  it "keeps audit history while protected items exist" do
    migration = described_class.new
    allow(migration).to receive(:table_exists?).with(:privacy_vault_items).and_return(true)
    allow(migration).to receive(:select_value).and_return(1)
    allow(migration).to receive(:drop_table)

    expect { migration.down }.to raise_error(ActiveRecord::IrreversibleMigration, /protected items exist/i)
    expect(migration).not_to have_received(:drop_table)
  end
end

RSpec.describe AddPrivacyVaultLeaseVersionToUsers do
  it "keeps lease support while protected items exist" do
    migration = described_class.new
    allow(migration).to receive(:table_exists?).with(:privacy_vault_items).and_return(true)
    allow(migration).to receive(:select_value).and_return(1)
    allow(migration).to receive(:remove_column)

    expect { migration.down }.to raise_error(ActiveRecord::IrreversibleMigration, /protected items exist/i)
    expect(migration).not_to have_received(:remove_column)
  end
end
