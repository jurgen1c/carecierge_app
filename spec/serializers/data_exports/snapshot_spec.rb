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
