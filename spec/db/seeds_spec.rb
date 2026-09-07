require "rails_helper"

RSpec.describe "Rails seeds" do
  let(:environment) { "development" }
  let(:development_seeds) { nil }
  let(:production_password) { "Production-test-only-105!" }

  around { |example| Timecop.freeze(Time.zone.local(2026, 9, 6, 12)) { example.run } }

  before do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new(environment))
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("DEVELOPMENT_SEEDS").and_return(development_seeds)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("PRODUCTION_SEED_PASSWORD").and_return(production_password)
    allow(ENV).to receive(:fetch).with("REFERENCE_DATE", "2026-09-06").and_return("2026-09-05")
  end

  def seed
    load Rails.root.join("db/seeds.rb")
  end

  it "keeps ordinary development seeds limited to baseline data" do
    expect { seed }.not_to change(User, :count)
    expect(RelationshipTemplate.count).to be_positive
    expect(FeatureFlag.find_by!(key: "ai_memory_extraction")).not_to be_enabled
  end

  context "with development scenarios requested" do
    let(:development_seeds) { "true" }

    it "loads the development file through db:seed, preserves flags, and supports reruns" do
      flag = create(:feature_flag, key: "ai_memory_extraction", enabled: true)
      seed
      expect(User.count).to eq(6)
      expect(Reminder.pluck(:scheduled_at).uniq).to eq([ Time.zone.local(2026, 9, 6, 12) ])
      expect { seed }.not_to change(User, :count)
      expect(flag.reload).to be_enabled
    end

    %w[production test].each do |env|
      context "in #{env}" do
        let(:environment) { env }

        it "refuses the request before running even the baseline seeds" do
          expect(RelationshipTemplate).not_to receive(:install_defaults!)
          expect(FeatureFlag).not_to receive(:find_or_create_by!)
          expect { seed }.to raise_error(ArgumentError, /development/)
        end
      end
    end
  end

  context "in production without development scenarios" do
    let(:environment) { "production" }

    it "installs the baseline and provisions only Jurgen without sending email" do
      expect(ActionMailer::MessageDelivery).not_to receive(:new)
      expect(ActiveJob::Base.queue_adapter).not_to receive(:enqueue)
      seed
      expect(User.count).to eq(1)
      user = User.find_by!(email: "jurgen1c@gmail.com")
      expect(user.valid_password?(production_password)).to be(true)
      expect(user).not_to be_admin
      expect(user).not_to be_confirmed
      expect(RelationshipTemplate.count).to be_positive
      expect(FeatureFlag.find_by!(key: "ai_memory_extraction")).not_to be_enabled
    end

    it "preserves existing accounts and does not require a password on reruns" do
      user = create(:user, email: "jurgen1c@gmail.com", admin: true)
      other = create(:user)
      before_attributes = user.attributes
      expect(ENV).not_to receive(:fetch).with("PRODUCTION_SEED_PASSWORD")
      seed
      expect(User.pluck(:id)).to contain_exactly(user.id, other.id)
      expect(user.reload.attributes).to eq(before_attributes)
    end

    it "requires an explicit password to create the production account" do
      allow(ENV).to receive(:fetch).with("PRODUCTION_SEED_PASSWORD").and_raise(KeyError)
      expect { seed }.to raise_error(KeyError)
      expect(User.count).to eq(0)
    end

    it "preserves an existing mixed-case email without requiring a password" do
      user = create(:user, email: "jurgen1c@gmail.com", admin: true)
      user.update_column(:email, "Jurgen1c@gmail.com")
      before_attributes = user.reload.attributes
      expect(ENV).not_to receive(:fetch).with("PRODUCTION_SEED_PASSWORD")

      expect { seed }.not_to change(User, :count)

      expect(user.reload.attributes).to eq(before_attributes)
    end

    context "with an invalid password" do
      let(:production_password) { "" }

      it "rejects creation using the existing user validations" do
        expect { seed }.to raise_error(ActiveRecord::RecordInvalid)
        expect(User.count).to eq(0)
      end
    end
  end
end
