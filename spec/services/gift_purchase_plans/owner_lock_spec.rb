require "rails_helper"

RSpec.describe "Gift purchase owner lock compatibility", type: :model do
  self.use_transactional_tests = false

  it "allows foreign-key readers while saving purchase logistics" do
    verify_foreign_key_compatibility do |gift, _event|
      GiftPurchasePlans::Save.call(gift:, attributes: { budget: "25" }, expected_version: "new")
    end
  end

  it "allows foreign-key readers while attaching a purchase task" do
    verify_foreign_key_compatibility(persisted_plan: true) do |gift, event|
      GiftPurchasePlans::AddTask.call(gift:, event_plan: event)
    end
  end

  def verify_foreign_key_compatibility(persisted_plan: false)
    owner = create(:user)
    profile = create(:relationship_profile, user: owner)
    gift = create(:gift, relationship_profile: profile)
    event = create(:event_plan, user: owner, relationship_profile: profile)
    GiftPurchasePlan.create!(gift:) if persisted_plan
    observed_reader = false

    allow(profile).to receive(:with_lock).and_wrap_original do |original, *arguments, &block|
      # PostgreSQL FK checks take this lock. A concurrent reminder holds the
      # profile lock before inserting its user FK; it must not wait on this owner.
      reader = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          User.transaction { User.where(id: owner.id).lock("FOR KEY SHARE NOWAIT").pick(:id) }
        end
      end
      reader.report_on_exception = false
      expect(reader.value).to eq(owner.id)
      observed_reader = true
      original.call(*arguments, &block)
    end

    yield gift, event
    expect(observed_reader).to be(true)
  ensure
    owner&.destroy!
  end
end
