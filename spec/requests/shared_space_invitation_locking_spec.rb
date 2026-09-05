require "rails_helper"

RSpec.describe "Shared-space invitation locking", type: :request do
  self.use_transactional_tests = false

  it "holds the creator account before persistence while permitting foreign-key readers" do
    owner = create(:user)
    sign_in owner
    observed_lock = false
    allow_any_instance_of(SharedRelationshipSpace).to receive(:save).and_wrap_original do |original, *arguments, &block|
      %w[UPDATE NO\ KEY\ UPDATE KEY\ SHARE].each do |mode|
        contender = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            User.transaction { User.where(id: owner.id).lock("FOR #{mode} NOWAIT").pick(:id) }
          rescue ActiveRecord::LockWaitTimeout
            :blocked
          end
        end
        contender.report_on_exception = false
        expect(contender.value).to eq(mode == "KEY SHARE" ? owner.id : :blocked)
      end
      observed_lock = true
      original.call(*arguments, &block)
    end

    post shared_relationship_spaces_path, params: { shared_relationship_space: { title: "Our invitation", invited_email: "invitee@example.test" } }
    expect(response).to redirect_to(shared_relationship_space_path(SharedRelationshipSpace.sole))
    expect(observed_lock).to be(true)
  ensure
    RSpec::Mocks.space.reset_all
    owner&.destroy!
  end
end
