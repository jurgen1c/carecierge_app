require "rails_helper"

RSpec.describe "Shared memory correction", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:memory) { profile.memory_records.create!(title: "Tea", body: "Black tea", reviewed_at: Time.current, high_impact_automation_approved_at: Time.current) }

  context "with committed correction transactions" do
    self.use_transactional_tests = false

    after { user.destroy! }

    it "holds the owner lock before locking the profile and writing the correction" do
      memory
      owner_locked = false
      profile_locked = false
      violations = []
      observer = lambda do |*, payload|
        sql = payload[:sql]
        if sql.match?(/\A(?:BEGIN|COMMIT|ROLLBACK)\b/)
          owner_locked = false
          profile_locked = false
        end
        if sql.include?('FROM "users"') && sql.include?("FOR NO KEY UPDATE")
          owner_locked = true
        elsif sql.include?('FROM "relationship_profiles"') && sql.match?(/FOR (?:NO KEY )?UPDATE/)
          violations << sql unless owner_locked
          profile_locked = true
        elsif sql.start_with?('UPDATE "memory_records"', 'INSERT INTO "memory_revisions"')
          violations << sql unless owner_locked && profile_locked
        end
      end
      ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
        expect(MemoryRecords::Update.call(user:, memory_record: memory, attributes: { body: "Green tea" })).to be(true)
      end
      expect(memory.reload.body).to eq("Green tea")
      expect(memory.memory_revisions.sole.previous_body).to eq("Black tea")
      expect(violations).to be_empty
    end
  end

  it "records a revision and resets trust when the owner corrects a memory" do
    expect do
      MemoryRecords::Update.call(user:, memory_record: memory, attributes: { body: "Green tea" }, correction_note: "Clarified today")
    end.to change(MemoryRevision, :count).by(1)

    expect(memory.reload).to have_attributes(body: "Green tea", source: "user_corrected", status: "corrected",
      reviewed_at: nil, high_impact_automation_approved_at: nil)
    expect(memory.memory_revisions.sole).to have_attributes(previous_body: "Black tea", revised_body: "Green tea", user:)
  end

  it "does not manufacture a correction for normalized unchanged content" do
    memory
    expect do
      MemoryRecords::Update.call(user:, memory_record: memory, attributes: { body: " Black tea " })
    end.not_to change(MemoryRevision, :count)
    expect(memory.reload.source).to eq("user_confirmed")
  end

  it "rejects another owner before changing content" do
    expect do
      MemoryRecords::Update.call(user: create(:user), memory_record: memory, attributes: { body: "Foreign" })
    end.to raise_error(Pundit::NotAuthorizedError)
    expect(memory.reload.body).to eq("Black tea")
  end
end
