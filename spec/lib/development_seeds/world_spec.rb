require "rails_helper"
require Rails.root.join("lib/development_seeds/world")

RSpec.describe DevelopmentSeeds::World do
  subject(:world) { described_class.new(reference_date: "2026-09-06") }

  around { |example| Timecop.freeze(Time.zone.local(2026, 9, 6, 12)) { example.run } }

  it "refuses production before any mutation" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    expect { world.seed! }.to raise_error(DevelopmentSeeds::World::UnsafeEnvironment)
    expect { world.reset! }.to raise_error(DevelopmentSeeds::World::UnsafeEnvironment)
    expect(User.count).to eq(0)
  end

  context "in development" do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
    end

    it "creates repeatable isolated personas without email, jobs or network" do
      expect(Net::HTTP).not_to receive(:start)
      expect(Net::HTTP).not_to receive(:new)
      expect(ActionMailer::MessageDelivery).not_to receive(:new)
      expect(ActiveJob::Base.queue_adapter).not_to receive(:enqueue)
      expect(ActiveJob::Base.queue_adapter).not_to receive(:enqueue_at)
      expect(MessageDrafts::OpenAiGenerator).not_to receive(:new)
      expect(RelationshipBriefings::OpenAiGenerator).not_to receive(:new)
      expect(GiftRecommendations::OpenAiGenerator).not_to receive(:new)
      world.seed!
      counts = ApplicationRecord.descendants.reject(&:abstract_class?).to_h { |model| [ model.name, model.count ] }
      world.seed!
      counts.each { |name, count| expect(name.constantize.count).to eq(count), name }
      expect(world.users.keys).to include("new_en", "new_es", "owner_en", "owner_es", "admin", "vendor")
      expect(world.users.fetch("new_en")).to be_onboarding_pending
      expect(world.users.fetch("owner_en")).not_to be_onboarding_pending
      expect(world.users.fetch("owner_en").relationship_profiles.pluck(:id) & world.users.fetch("owner_es").relationship_profiles.pluck(:id)).to be_empty
      expect(ActionMailer::Base.deliveries).to be_empty
      expect(world.users.fetch("owner_en").messaging_connection.access_token).to be_nil
      expect(world.users.fetch("owner_en").vault_mfa_credential).to be_nil
    end

    it "preserves unrelated accounts and feature flag assignments when reset" do
      other = create(:user)
      profile = create(:relationship_profile, user: other)
      flag = create(:feature_flag, enabled: true)
      world.seed!
      world.reset!
      expect(User.pluck(:id)).to eq([ other.id ])
      expect(profile.reload).to be_persisted
      expect(flag.reload).to be_enabled
    end

    it "refuses reset atomically when a developer adds dependent data" do
      world.seed!
      profile = create(:relationship_profile, user: world.users.fetch("owner_en"))
      count = User.count
      expect { world.reset! }.to raise_error(DevelopmentSeeds::World::OwnershipConflict)
      expect(User.count).to eq(count)
      expect(profile.reload).to be_persisted
      expect(SharedRelationshipSpace.count).to eq(2)
    end

    it "refuses reset after a seed record is moved to an unrelated account" do
      world.seed!
      other = create(:user)
      profile = world.users.fetch("owner_en").relationship_profiles.find_by!(relationship_mode: "professional")
      profile.update!(user: other)
      expect { world.reset! }.to raise_error(DevelopmentSeeds::World::OwnershipConflict)
      expect(profile.reload.user).to eq(other)
      expect(User.count).to eq(7)
    end

    it "uses the chosen reference date and refuses invalid dates" do
      world.seed!
      expect(Reminder.pluck(:scheduled_at).uniq).to eq([ Time.zone.local(2026, 9, 7, 12) ])
      expect { described_class.new(reference_date: "invalid") }.to raise_error(Date::Error)
    end

    it "refuses to claim an existing account with a synthetic email" do
      other = create(:user, email: "owner_en@carecierge.example")
      expect { world.seed! }.to raise_error(DevelopmentSeeds::World::OwnershipConflict)
      expect(other.reload).not_to be_admin
    end
  end
end
