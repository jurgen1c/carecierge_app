require "rails_helper"

RSpec.describe RemindersHelper, type: :helper do
  it "reuses timezone options within a minute and refreshes them after a half-hour DST transition" do
    cache = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(cache)
    expect(TZInfo::Timezone).to receive(:all_identifiers).twice.and_call_original

    Timecop.freeze(Time.utc(2026, 3, 8, 5, 29, 30)) do
      first_options = helper.reminder_time_zone_options
      second_options = helper.reminder_time_zone_options

      expect(second_options).to eq(first_options)
    end

    Timecop.freeze(Time.utc(2026, 3, 8, 5, 30, 30)) do
      expect(helper.reminder_time_zone_options).to be_present
    end
  end
end
