require "rails_helper"

RSpec.describe "concierge_conversations/_transcript", type: :view do
  let(:user) { create(:user) }
  let(:conversation) { ConciergeConversation.create!(user:) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Find the saved details", locale: "en", state: "completed") }

  %i[en es].each do |locale|
    it "renders preloaded receipts in execution order after an earlier action changes in #{locale}" do
      actions = Timecop.freeze do
        3.times.map do |index|
          turn.actions.create!(name: "memories.search", fingerprint: index.to_s * 64, state: "succeeded", result: { "records" => [] })
        end
      end
      actions.first.update!(result: { "records" => [], "query" => "Updated search" })
      expect(actions.first.execution_order).to be > actions.last.execution_order
      # Preloading does not promise database row order. Supply a valid cache in
      # creation order so the view must honor the persisted execution sequence.
      turn.association(:actions).target = actions
      allow(view).to receive(:current_user).and_return(user)

      I18n.with_locale(locale) do
        render partial: "concierge_conversations/transcript", locals: { conversation:, turns: [ turn ] }
      end

      receipts = Nokogiri::HTML.fragment(rendered).css("[data-concierge-action-id]")
      expect(receipts.map { |receipt| receipt["data-concierge-action-id"] }).to eq([ actions[1].id, actions[2].id, actions[0].id ])
      expect(turn.actions).to be_loaded
      expect(turn.actions.to_a).to eq(actions)
    end
  end
end
