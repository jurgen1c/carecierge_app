require "rails_helper"

RSpec.describe MessageDraftWorkspaceComponent, type: :component do
  it "does not prefill a failed personal generation's saved situation in professional mode" do
    profile = create(:relationship_profile)
    draft = create(:message_draft, user: profile.user, relationship_profile: profile, situation: "Personal medical discussion")
    profile.update!(relationship_mode: "professional")
    render_inline described_class.new(relationship_profile: profile, message_draft: draft.reload)
    expect(page).to have_field("Message or situation", with: "")
    expect(page).not_to have_text("Personal medical discussion")
  end
end

RSpec.describe EventPlanWorkspaceComponent, type: :component do
  %w[personal professional].each do |mode|
    it "offers sensitive event sources only in personal mode (#{mode})" do
      profile = create(:relationship_profile, relationship_mode: mode)
      plan = create(:event_plan, user: profile.user, relationship_profile: profile)
      note = create(:relationship_note, relationship_profile: profile, private: true)
      vault_item = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "allowed")
      render_inline described_class.new(event_plan: plan, event_plans: [ plan ], plan_task: plan.plan_tasks.new,
        private_notes: [ note ], vault_items: [ vault_item ], vault_unlocked: true)
      %w[event_plan_suggestion backup_plan].each do |form|
        %w[private_note_ids vault_item_ids].each do |field|
          selector = "input[name='#{form}[#{field}][]']"
          if mode == "professional"
            expect(page).not_to have_css(selector, visible: :all)
          else
            expect(page).to have_css(selector, visible: :all)
          end
        end
      end
    end
  end
end
