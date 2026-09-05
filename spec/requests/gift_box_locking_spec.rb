require "rails_helper"

RSpec.describe "Gift box deletion locking", type: :request do
  self.use_transactional_tests = false

  it "holds the account before the profile while allowing concurrent foreign-key readers" do
    owner = create(:user)
    profile = create(:relationship_profile, user: owner)
    box = profile.gift_boxes.create!(name: "Reading box", occasion: "Birthday", items_attributes: [ { name: "Book" } ])
    sign_in owner
    observed_lock = false

    allow_any_instance_of(RelationshipProfile).to receive(:with_lock).and_wrap_original do |original, *arguments, &block|
      # Account deletion takes FOR UPDATE; box/item writes use NO KEY UPDATE.
      # Neither can acquire the account while this deletion is entering its profile lock.
      %w[UPDATE NO\ KEY\ UPDATE].each do |mode|
        contender = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            User.transaction { User.where(id: owner.id).lock("FOR #{mode} NOWAIT").pick(:id) }
          rescue ActiveRecord::LockWaitTimeout
            :blocked
          end
        end
        contender.report_on_exception = false
        expect(contender.value).to eq(:blocked)
      end
      reader = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          User.transaction { User.where(id: owner.id).lock("FOR KEY SHARE NOWAIT").pick(:id) }
        end
      end
      reader.report_on_exception = false
      expect(reader.value).to eq(owner.id)
      observed_lock = true
      original.call(*arguments, &block)
    end

    delete relationship_profile_gift_box_path(profile, box)
    expect(response).to redirect_to(relationship_profile_gift_boxes_path(profile))
    expect(observed_lock).to be(true)
    expect(GiftBoxItem.where(gift_box_id: box.id)).to be_empty
  ensure
    RSpec::Mocks.space.reset_all
    owner&.destroy!
  end
end
