require "rails_helper"

RSpec.describe "Professional generation form modes", type: :request do
  %w[briefing gift alternative event backup].each do |surface|
    [ %w[personal professional], %w[professional personal] ].each do |before_mode, after_mode|
      it "rejects a stale #{before_mode} #{surface} form after switching to #{after_mode}" do
        user = create(:user)
        profile = create(:relationship_profile, user:, relationship_mode: before_mode,
          professional_context: { "gifts_allowed" => "1", "boundaries" => "Office stationery only" })
        plan = create(:event_plan, user:, relationship_profile: profile)
        recommendation = create(:gift_recommendation, user:, relationship_profile: profile, relationship_mode: before_mode)
        create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
        sign_in user
        get surface.in?(%w[event backup]) ? event_plan_path(plan) : relationship_profile_path(profile)
        field = { "briefing" => "relationship_briefing", "gift" => "gift_recommendation", "alternative" => "gift_recommendation", "event" => "event_plan_suggestion", "backup" => "backup_plan" }.fetch(surface)
        input = Nokogiri::HTML(response.body).at_css("input[name='#{field}[relationship_mode]']")
        expect(input&.[]("value")).to eq(before_mode)
        profile.update!(relationship_mode: after_mode)
        case surface
        when "briefing"
          expect_any_instance_of(RelationshipBriefings::OpenAiGenerator).not_to receive(:generate)
          post generate_relationship_profile_relationship_briefings_path(profile), params: {
            relationship_briefing: { interaction_context: "Stale private situation", relationship_mode: before_mode }
          }
        when "gift", "alternative"
          expect_any_instance_of(GiftRecommendations::OpenAiGenerator).not_to receive(:generate)
          path = surface == "gift" ? generate_relationship_profile_gift_recommendations_path(profile) : alternative_relationship_profile_gift_recommendation_path(profile, recommendation)
          post path, params: { gift_recommendation: { occasion: "Stale private occasion", relationship_mode: before_mode } }
        when "event"
          expect_any_instance_of(EventPlans::LlmSuggester).not_to receive(:generate)
          post suggest_event_plan_path(plan), params: { event_plan_suggestion: { relationship_mode: before_mode } }
        when "backup"
          expect_any_instance_of(BackupPlans::LlmGenerator).not_to receive(:generate)
          post generate_event_plan_backup_plans_path(plan), params: { backup_plan: { scenario: BackupPlan::SCENARIOS.first, relationship_mode: before_mode } }
        end
        expect(response).to have_http_status(:redirect)
        follow_redirect!
        expect(response.body).not_to include("Stale private situation", "Stale private occasion")
        expect(RelationshipBriefing.count).to eq(0)
        expect(GiftRecommendation.count).to eq(1)
        expect(BackupPlan.count).to eq(0)
      end
    end
  end
end
