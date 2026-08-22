require "rails_helper"

RSpec.describe DataExports::Snapshot do
  it "preloads plan tasks for relationship exports" do
    profile = create(:relationship_profile)
    2.times do
      plan = create(:event_plan, user: profile.user, relationship_profile: profile)
      create(:plan_task, event_plan: plan)
    end

    queries = capture_sql do
      described_class.new(user: profile.user, relationship_profile: profile.reload).to_h
    end
    task_queries = queries.select { |query| query.include?('FROM "plan_tasks"') }

    expect(task_queries.length).to eq(1)
  end

  it "exports attached personal touch checklists and their items" do
    profile = create(:relationship_profile)
    important_date = create(:important_date, relationship_profile: profile)
    checklist = create(
      :personal_touch_checklist,
      relationship_profile: profile,
      event_plan: nil,
      important_date:
    )
    item = create(:personal_touch_item, personal_touch_checklist: checklist, category: "follow_up")

    snapshot = described_class.new(user: profile.user, relationship_profile: profile).to_h
    exported = snapshot.fetch("relationship_profiles").sole.fetch("personal_touch_checklists").sole

    expect(exported).to include("moment_type" => "ImportantDate", "moment_id" => important_date.id)
    expect(exported.fetch("items").sole).to include("id" => item.id, "category" => "follow_up")
  end

  private

  def capture_sql
    queries = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached]

      queries << payload[:sql]
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
    queries
  end
end
