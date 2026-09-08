class PersonCardComponent < ApplicationViewComponent
  option :profile
  option :summaries

  style do
    base { %w[person-card workspace-panel] }
  end

  def last_interaction_on
    summaries.last_interaction_on(profile)
  end

  def next_moment
    @next_moment ||= summaries.next_moment(profile)
  end
end
