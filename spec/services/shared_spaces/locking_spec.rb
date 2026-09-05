require "rails_helper"

RSpec.describe "Shared-space account locking", type: :service do
  self.use_transactional_tests = false

  [ :save, :accept, :end_sharing ].each do |action|
    it "serializes #{action} with account deletion while allowing foreign-key readers" do
      space = create(:shared_relationship_space)
      owner, partner = space.owner, space.partner
      actor = partner
      space.update!(partner: nil, accepted_at: nil) if action == :accept
      observed_lock = false

      allow(space).to receive(:with_lock).and_wrap_original do |original, *arguments, &block|
        %w[UPDATE NO\ KEY\ UPDATE KEY\ SHARE].each do |mode|
          contender = Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              User.transaction { User.where(id: actor.id).lock("FOR #{mode} NOWAIT").pick(:id) }
            rescue ActiveRecord::LockWaitTimeout
              :blocked
            end
          end
          contender.report_on_exception = false
          expect(contender.value).to eq(mode == "KEY SHARE" ? actor.id : :blocked)
        end
        observed_lock = true
        original.call(*arguments, &block)
      end

      case action
      when :save
        SharedSpaces::ChangeItem.call(space:, actor:, attributes: { kind: "note", title: "Shared choice" })
      when :accept
        space.accept!(actor)
      when :end_sharing
        space.end_sharing!(actor)
      end
      expect(observed_lock).to be(true)
    ensure
      RSpec::Mocks.space.reset_all
      owner&.destroy!
      partner&.destroy!
    end
  end
end
