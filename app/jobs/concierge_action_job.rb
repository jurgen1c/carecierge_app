class ConciergeActionJob < ApplicationJob
  queue_as :default

  def perform(action_id)
    action = ConciergeAction.find_by(id: action_id)
    Concierge::ProviderExecution.call(action:) if action
  end
end
