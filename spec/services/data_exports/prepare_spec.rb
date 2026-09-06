require "rails_helper"

RSpec.describe DataExports::Prepare, type: :model do
  self.use_transactional_tests = false

  [ false, true ].each do |include_sensitive|
    it "#{include_sensitive ? 'blocks' : 'allows'} concurrent account updates while rendering a #{include_sensitive ? 'sensitive' : 'redacted'} snapshot" do
      password = "known-password123"
      owner = create(:user, password:)
      snapshot = DataExports::Snapshot.new(user: owner, relationship_profile: nil, include_sensitive:, include_file_contents: true)
      allow(DataExports::Snapshot).to receive(:new).and_return(snapshot)
      observed = false

      allow(snapshot).to receive(:to_h).and_wrap_original do |original|
        reader = Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            User.transaction { User.where(id: owner.id).lock("FOR UPDATE NOWAIT").pick(:id) }
          end
        end
        reader.report_on_exception = false
        if include_sensitive
          expect { reader.value }.to raise_error(ActiveRecord::LockWaitTimeout)
        else
          expect(reader.value).to eq(owner.id)
        end
        observed = true
        original.call
      end

      result = described_class.call(user: owner, relationship_profile: nil, format: "json", include_sensitive:, password:)
      expect(result.error).to be_nil
      expect(result.snapshot).to be_present
      expect(observed).to be(true)
    ensure
      owner&.destroy!
    end
  end
end
