require "rails_helper"
require Rails.root.join("db/migrate/20260909045534_add_concierge_origin_required_to_generated_records")

RSpec.describe AddConciergeOriginRequiredToGeneratedRecords do
  around do |example|
    ActiveRecord::Migration.suppress_messages { example.run }
  ensure
    [ DraftRevision, RelationshipBriefing, GiftRecommendation ].each(&:reset_column_information)
    described_class::StoredAction.reset_column_information
  end

  it "reversibly marks existing chat outputs without retaining conversation data or changing content" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    draft = create(:message_draft, user:, relationship_profile: profile)
    records = [ create(:draft_revision, message_draft: draft),
      create(:relationship_briefing, user:, relationship_profile: profile),
      create(:gift_recommendation, user:, relationship_profile: profile) ]
    legacy = create(:gift_recommendation, user:, relationship_profile: profile)
    conversation = ConciergeConversation.create!(user:)
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Prepare ideas", locale: "en")
    records.zip(%w[drafts.generate briefings.generate gift_ideas.generate]).each do |record, name|
      turn.actions.create!(name:, fingerprint: SecureRandom.hex(32), state: "succeeded",
        result: { "record" => { "record_type" => record.class.name, "id" => record.id } })
    end
    before = records.map { |record| record.attributes.except("concierge_origin_required") }
    migration = described_class.new
    migration.migrate(:down)
    migration.migrate(:up)
    records.each(&:reload)
    expect(records).to all(have_attributes(concierge_origin_required: true))
    expect(legacy.reload.concierge_origin_required).to be(false)
    expect(records.map { |record| record.attributes.except("concierge_origin_required") }).to eq(before)
    conversation.destroy!
    expect(records.map(&:reload)).to all(have_attributes(concierge_origin_required: true))
  end
end
