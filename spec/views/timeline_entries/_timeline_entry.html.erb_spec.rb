require "rails_helper"

RSpec.describe "timeline_entries/_timeline_entry", type: :view do
  it "reuses one policy lookup while rendering available actions" do
    profile = build_stubbed(:relationship_profile)
    timeline_entry = build_stubbed(:timeline_entry, relationship_profile: profile)
    timeline_entry_policy = instance_double(TimelineEntryPolicy, update?: true, destroy?: true)
    policy_lookups = 0
    view.define_singleton_method(:policy) do |record|
      raise "unexpected policy record" unless record == timeline_entry

      policy_lookups += 1
      timeline_entry_policy
    end

    render partial: "timeline_entries/timeline_entry", locals: {
      relationship_profile: profile,
      timeline_entry:,
      selected_type: nil
    }

    expect(policy_lookups).to eq(1)
  end
end
