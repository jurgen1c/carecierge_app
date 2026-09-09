require "rails_helper"
require Rails.root.join("db/migrate/20260908180644_add_source_keys_to_concierge_actions")

RSpec.describe AddSourceKeysToConciergeActions do
  around do |example|
    ActiveRecord::Migration.suppress_messages { example.run }
  ensure
    ConciergeAction.reset_column_information
    described_class::StoredAction.reset_column_information
  end

  it "reversibly indexes existing encrypted generation outcomes without changing their content" do
    user = create(:user)
    conversation = ConciergeConversation.create!(user:)
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Prepare a draft", locale: "en")
    revision_id = SecureRandom.uuid
    payload = { "record" => { "record_type" => "DraftRevision", "id" => revision_id, "body" => "An existing work draft" },
      "authorization_version" => "a" * 64 }
    action = turn.actions.create!(name: "drafts.generate", fingerprint: "b" * 64, state: "succeeded", result: payload)
    expected_keys = action.source_keys
    migration = described_class.new
    migration.migrate(:down)
    expect(ActiveRecord::Base.connection.column_exists?(:concierge_actions, :source_keys)).to be(false)
    migration.migrate(:up)
    expect(action.reload.source_keys).to eq(expected_keys)
    expect(action.result).to eq(payload)
    expect(action.source_keys).to eq([ Digest::SHA256.hexdigest("DraftRevision:#{revision_id}") ])
    expect(ActiveRecord::Base.connection.indexes(:concierge_actions).find { |index| index.columns == [ "source_keys" ] }.using).to eq(:gin)
  end
end
