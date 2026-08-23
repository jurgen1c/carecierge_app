require "rails_helper"

RSpec.describe "Event plans", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:, first_name: "Maya") }

  before { sign_in user }

  it "prefills an owner-scoped birthday plan from an important date" do
    important_date = create(
      :important_date,
      relationship_profile: profile,
      date_type: "birthday",
      starts_on: Date.new(2020, 9, 12),
      recurrence: "yearly"
    )

    travel_to Time.zone.local(2026, 8, 22, 10) do
      get new_event_plan_path(relationship_profile_id: profile.id, important_date_id: important_date.id)
    end

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css("input#event_plan_relationship_profile_id[type='hidden']")["value"]).to eq(profile.id)
    expect(response.parsed_body.at_css("select#event_plan_relationship_profile_id")).to be_nil
    expect(response.parsed_body.at_css("#event_plan_title")["value"]).to eq("#{profile.display_name}'s birthday")
    expect(response.parsed_body.at_css("input#event_plan_occasion_type[type='hidden']")["value"]).to eq("birthday")
    expect(response.parsed_body.at_css("select#event_plan_occasion_type")).to be_nil
    expect(response.body).to include("Set from this birthday date")
    expect(response.parsed_body.at_css("#event_plan_starts_on")["value"]).to eq("2026-09-12")
  end

  it "prefills the birthday occurrence using the owner's local calendar date" do
    create(:notification_preference, user:, time_zone: "America/Los_Angeles")
    important_date = create(
      :important_date,
      relationship_profile: profile,
      date_type: "birthday",
      starts_on: Date.new(2020, 8, 22),
      recurrence: "yearly"
    )

    travel_to Time.utc(2026, 8, 23, 2) do
      get new_event_plan_path(relationship_profile_id: profile.id, important_date_id: important_date.id)
    end

    expect(response.parsed_body.at_css("#event_plan_starts_on")["value"]).to eq("2026-08-22")
  end

  it "does not prefill a birthday plan from another user's important date" do
    foreign_date = create(:important_date, date_type: "birthday")

    get new_event_plan_path(relationship_profile_id: profile.id, important_date_id: foreign_date.id)

    expect(response).to have_http_status(:not_found)
  end

  it "preserves the authorized important date as birthday-plan provenance" do
    important_date = create(:important_date, relationship_profile: profile, date_type: "birthday")

    expect do
      post event_plans_path, params: {
        important_date_id: important_date.id,
        event_plan: {
          relationship_profile_id: profile.id,
          title: "#{profile.display_name}'s birthday",
          occasion_type: "birthday",
          starts_on: important_date.next_occurrence_on.iso8601
        }
      }
    end.to change(EventPlan, :count).by(1)

    expect(EventPlan.order(:created_at).last.source_context).to eq(
      [
        {
          "id" => "important_date:#{important_date.id}",
          "label" => "Important date",
          "role" => "birthday_origin"
        }
      ]
    )
  end

  it "keeps an important-date birthday occasion immutable when editing" do
    important_date = create(:important_date, relationship_profile: profile, date_type: "birthday")
    post event_plans_path, params: {
      important_date_id: important_date.id,
      event_plan: {
        relationship_profile_id: profile.id,
        title: "#{profile.display_name}'s birthday",
        occasion_type: "birthday",
        starts_on: important_date.next_occurrence_on.iso8601
      }
    }
    plan = EventPlan.order(:created_at).last
    original_tasks = plan.plan_tasks.order(:position).pluck(:title)

    get edit_event_plan_path(plan)

    expect(response.parsed_body.at_css("input#event_plan_occasion_type[type='hidden']")["value"]).to eq("birthday")
    expect(response.parsed_body.at_css("select#event_plan_occasion_type")).to be_nil
    expect(response.body).to include("Set from this birthday date")

    patch event_plan_path(plan), params: { event_plan: { occasion_type: "custom" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(plan.reload.occasion_type).to eq("birthday")
    expect(plan.source_context.sole).to include("role" => "birthday_origin")
    expect(plan.plan_tasks.order(:position).pluck(:title)).to eq(original_tasks)
  end

  it "does not create a plan from another user's important date" do
    foreign_date = create(:important_date, date_type: "birthday")

    expect do
      post event_plans_path, params: {
        important_date_id: foreign_date.id,
        event_plan: {
          relationship_profile_id: profile.id,
          title: "Foreign birthday",
          occasion_type: "birthday"
        }
      }
    end.not_to change(EventPlan, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "does not attach birthday-date provenance to another occasion" do
    important_date = create(:important_date, relationship_profile: profile, date_type: "birthday")

    expect do
      post event_plans_path, params: {
        important_date_id: important_date.id,
        event_plan: {
          relationship_profile_id: profile.id,
          title: "Different occasion",
          occasion_type: "custom"
        }
      }
    end.not_to change(EventPlan, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "renders an owner-scoped global planning workspace" do
    owned = create(:event_plan, user:, relationship_profile: profile, title: "Maya's birthday dinner")
    foreign = create(:event_plan, title: "Private foreign plan")

    get event_plans_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Maya", new_event_plan_path)
    expect(response.body).not_to include(foreign.title)
    expect(response.body).to include(event_plan_path(owned))
  end

  it "disables Turbo snapshots on every event-plan surface" do
    plan = create(:event_plan, user:, relationship_profile: profile)

    [ event_plans_path, new_event_plan_path, edit_event_plan_path(plan), event_plan_path(plan) ].each do |path|
      get path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css("meta[name='turbo-cache-control']")&.[]("content")).to eq("no-cache")
    end
  end

  it "creates a reusable templated plan for an owned active relationship" do
    expect do
      post event_plans_path, params: {
        event_plan: {
          relationship_profile_id: profile.id,
          title: "Maya's birthday dinner",
          occasion_type: "birthday",
          starts_on: "2026-09-12",
          budget: "150.00",
          guest_list: "Maya and Alex",
          notes: "Keep it relaxed."
        }
      }
    end.to change(user.event_plans, :count).by(1).and change(PlanTask, :count).by(9)

    plan = EventPlan.find_by!(user:, relationship_profile: profile)
    expect(response).to redirect_to(event_plan_path(plan))
    expect(plan).to have_attributes(budget_cents: 15_000, relationship_profile_id: profile.id)
  end

  it "returns a form error when the budget is not numeric" do
    submitted_budget = "not-a-budget"

    expect do
      post event_plans_path, params: {
        event_plan: {
          relationship_profile_id: profile.id,
          title: "Maya's birthday dinner",
          occasion_type: "birthday",
          budget: submitted_budget
        }
      }
    end.not_to change(EventPlan, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Budget cents")
    expect(response.parsed_body.at_css("#event_plan_budget")["value"]).to eq(submitted_budget)
  end

  it "rejects an oversized scientific budget before materializing an integer" do
    expect_any_instance_of(BigDecimal).not_to receive(:round)

    expect do
      post event_plans_path, params: {
        event_plan: {
          relationship_profile_id: profile.id,
          title: "Maya's birthday dinner",
          occasion_type: "birthday",
          budget: "1e999999999"
        }
      }
    end.not_to change(EventPlan, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "adds derived template deadlines when an undated plan is scheduled" do
    plan = EventPlans::Create.call(
      user:,
      relationship_profile: profile,
      attributes: { title: "Maya's dinner", occasion_type: "custom", starts_on: nil }
    )

    patch event_plan_path(plan), params: { event_plan: { starts_on: "2026-10-12" } }

    expect(response).to redirect_to(event_plan_path(plan))
    expect(plan.plan_tasks.reload.order(:position).pluck(:due_on)).to eq(
      EventPlans::Template::GENERIC_SEEDS.map { |seed| Date.new(2026, 10, 12) - seed.days_before.days }
    )
  end

  it "rebases derived template deadlines without overwriting a customized deadline" do
    plan = EventPlans::Create.call(
      user:,
      relationship_profile: profile,
      attributes: { title: "Maya's dinner", occasion_type: "custom", starts_on: Date.new(2026, 9, 12) }
    )
    derived_task, customized_task = plan.plan_tasks.order(:position).first(2)
    customized_task.update!(due_on: Date.new(2026, 9, 1))

    patch event_plan_path(plan), params: { event_plan: { starts_on: "2026-10-12" } }

    expect(derived_task.reload.due_on).to eq(Date.new(2026, 8, 31))
    expect(customized_task.reload.due_on).to eq(Date.new(2026, 9, 1))
  end

  it "does not allow another user's relationship context" do
    foreign_profile = create(:relationship_profile)

    post event_plans_path, params: {
      event_plan: { relationship_profile_id: foreign_profile.id, title: "Foreign", occasion_type: "custom" }
    }

    expect(response).to have_http_status(:not_found)
    expect(user.event_plans).to be_empty
  end

  it "excludes archived relationships from plan reads and mutations" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    profile.archive!

    get event_plans_path
    expect(response.body).not_to include(plan.title)

    get event_plan_path(plan)
    expect(response).to have_http_status(:not_found)

    patch event_plan_path(plan), params: { event_plan: { title: "Mutated archived plan" } }
    expect(response).to have_http_status(:not_found)

    post event_plan_plan_tasks_path(plan), params: {
      plan_task: { phase: "decide", kind: "task", title: "Archived task" }
    }
    expect(response).to have_http_status(:not_found)
  end

  it "revalidates the relationship after locking a plan mutation" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    allow_any_instance_of(RelationshipProfile).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      profile.update_column(:discarded_at, Time.current)
      method.call(*args, &block)
    end

    patch event_plan_path(plan), params: { event_plan: { title: "Too late" } }

    expect(response).to have_http_status(:not_found)
    expect(plan.reload.title).not_to eq("Too late")
  end

  it "rejects a stale plan update after a concurrent archive acquires the lock first" do
    plan = create(:event_plan, user:, relationship_profile: profile, title: "Original title")
    archived = false
    allow_any_instance_of(EventPlan).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      unless archived
        archived = true
        plan.update_columns(status: "archived", completed_at: nil)
      end
      method.call(*args, &block)
    end

    patch event_plan_path(plan), params: { event_plan: { title: "Too late" } }

    expect(response).to have_http_status(:not_found)
    expect(plan.reload.title).to eq("Original title")
  end

  it "revalidates the relationship after locking a task mutation" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    task = create(:plan_task, event_plan: plan)
    allow_any_instance_of(RelationshipProfile).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      profile.update_column(:discarded_at, Time.current)
      method.call(*args, &block)
    end

    patch event_plan_plan_task_path(plan, task), params: { plan_task: { title: "Too late" } }

    expect(response).to have_http_status(:not_found)
    expect(task.reload.title).not_to eq("Too late")
  end

  it "rejects stale task mutations after a concurrent archive acquires the plan lock first" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    task = create(:plan_task, event_plan: plan, title: "Original task")
    archived = false
    allow_any_instance_of(EventPlan).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      unless archived
        archived = true
        plan.update_columns(status: "archived", completed_at: nil)
      end
      method.call(*args, &block)
    end

    patch event_plan_plan_task_path(plan, task), params: { plan_task: { title: "Too late" } }

    expect(response).to have_http_status(:not_found)
    expect(task.reload.title).to eq("Original task")
  end

  it "rejects a stale task completion after a concurrent archive acquires the plan lock first" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    task = create(:plan_task, event_plan: plan)
    archived = false
    allow_any_instance_of(EventPlan).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      unless archived
        archived = true
        plan.update_columns(status: "archived", completed_at: nil)
      end
      method.call(*args, &block)
    end

    patch complete_event_plan_plan_task_path(plan, task)

    expect(response).to have_http_status(:not_found)
    expect(task.reload).not_to be_completed
  end

  it "does not render broken plan links on archived relationship profiles" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    profile.archive!

    get relationship_profile_path(profile)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(event_plan_path(plan))
  end

  it "does not advertise an unimplemented destroy route" do
    route = Rails.application.routes.routes.find do |candidate|
      candidate.defaults[:controller] == "event_plans" && candidate.defaults[:action] == "destroy"
    end

    expect(route).to be_nil
  end

  it "renders the hybrid runway with plan types, progress, decisions, reminders, and provenance" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    decision = create(:plan_task, event_plan: plan, kind: "decision", title: "Choose a restaurant")
    source = { "id" => "memory:123", "label" => "Relationship memory", "certainty" => "confirmed", "sensitive" => false }
    create(:plan_task, event_plan: plan, phase: "arrange", kind: "vendor_need", origin: "ai", source_context: [ source ])
    reminder = create(:reminder, user:, relationship_profile: profile, event_plan: plan, plan_task: decision)

    get event_plan_path(plan)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      "Planning runway", "Choose a restaurant", "Vendor need", "Outstanding decisions",
      reminder.title, "Relationship memory", "Suggest next steps"
    )
    reminder_link = response.parsed_body.css("a").find do |link|
      link.text.strip == "Create reminder" && link["href"].include?(decision.id)
    end
    expect(reminder_link["href"]).not_to include("title=")
  end

  it "updates and archives only owned plans" do
    plan = create(:event_plan, user:, relationship_profile: profile)

    patch event_plan_path(plan), params: { event_plan: { title: "Updated plan", occasion_type: "anniversary" } }
    expect(response).to redirect_to(event_plan_path(plan))
    expect(plan.reload).to have_attributes(title: "Updated plan", occasion_type: "anniversary", budget_cents: 15_000)

    patch archive_event_plan_path(plan)
    expect(response).to redirect_to(event_plans_path)
    expect(plan.reload).to be_archived
  end

  it "hides an archived plan from reads and further mutations while keeping archive idempotent" do
    plan = create(:event_plan, user:, relationship_profile: profile, status: "archived")
    task = create(:plan_task, event_plan: plan)

    get event_plan_path(plan)
    expect(response).to have_http_status(:not_found)

    patch event_plan_path(plan), params: { event_plan: { title: "Mutated archived plan" } }
    expect(response).to have_http_status(:not_found)

    post event_plan_plan_tasks_path(plan), params: {
      plan_task: { phase: "decide", kind: "task", title: "Archived task" }
    }
    expect(response).to have_http_status(:not_found)

    patch complete_event_plan_plan_task_path(plan, task)
    expect(response).to have_http_status(:not_found)

    patch archive_event_plan_path(plan)
    expect(response).to redirect_to(event_plans_path)
  end

  it "handles repeated reopen requests idempotently" do
    plan = create(:event_plan, user:, relationship_profile: profile, status: "completed", completed_at: Time.current)

    2.times do
      patch reopen_event_plan_path(plan)
      expect(response).to redirect_to(event_plan_path(plan))
    end

    expect(plan.reload).to be_active
  end

  it "handles a stale lifecycle transition without a server error" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    allow_any_instance_of(EventPlan).to receive(:complete!).and_wrap_original do |method, *args|
      plan.update_columns(status: "archived", completed_at: nil)
      method.call(*args)
    end

    patch complete_event_plan_path(plan)

    expect(response).to redirect_to(event_plans_path)
    expect(flash[:alert]).to eq("This event plan changed and that action is no longer available.")
  end

  it "adds, completes, reopens, updates, and deletes a manual plan task" do
    plan = create(:event_plan, user:, relationship_profile: profile)

    post event_plan_plan_tasks_path(plan), params: {
      plan_task: { phase: "decide", kind: "decision", title: "Choose the menu", due_on: "2026-09-01" }
    }
    task = plan.plan_tasks.reorder(created_at: :asc).last
    expect(task).to have_attributes(origin: "manual", title: "Choose the menu")

    patch complete_event_plan_plan_task_path(plan, task)
    expect(task.reload).to be_completed

    patch reopen_event_plan_plan_task_path(plan, task)
    expect(task.reload).not_to be_completed

    patch event_plan_plan_task_path(plan, task), params: { plan_task: { title: "Choose a vegetarian menu" } }
    expect(task.reload.title).to eq("Choose a vegetarian menu")

    reminder = create(:reminder, user:, relationship_profile: profile, event_plan: plan, plan_task: task)
    expect { delete event_plan_plan_task_path(plan, task) }.to change(PlanTask, :count).by(-1)
    expect(reminder.reload).to have_attributes(event_plan: plan, plan_task: nil)
  end

  it "reloads a concurrently changed task after acquiring the plan lock" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    task = create(:plan_task, event_plan: plan, title: "Original title")
    allow_any_instance_of(EventPlan).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      task.update!(title: "Concurrent title")
      method.call(*args, &block)
    end

    patch event_plan_plan_task_path(plan, task), params: { plan_task: { title: "Submitted title" } }

    expect(response).to redirect_to(event_plan_path(plan))
    expect(task.reload.title).to eq("Submitted title")
  end

  %i[patch delete].each do |request_method|
    it "rejects a stale #{request_method} after concurrent promotion supersedes the task" do
      plan = create(:event_plan, user:, relationship_profile: profile)
      task = create(:plan_task, event_plan: plan, title: "Current task")
      allow_any_instance_of(EventPlan).to receive(:with_lock).and_wrap_original do |method, *args, &block|
        task.update_column(:superseded_at, Time.current)
        method.call(*args, &block)
      end

      if request_method == :patch
        patch event_plan_plan_task_path(plan, task), params: { plan_task: { title: "Too late" } }
      else
        delete event_plan_plan_task_path(plan, task)
      end

      expect(response).to have_http_status(:not_found)
      expect(task.reload).to be_persisted
      expect(task.title).to eq("Current task")
    end
  end

  it "hides reminder creation for completed planning work" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    completed_task = create(:plan_task, event_plan: plan, completed_at: Time.current)
    active_task = create(:plan_task, event_plan: plan)

    get event_plan_path(plan)
    task_link = response.parsed_body.css("a").find { |link| link["href"]&.include?(completed_task.id) && link.text.include?("reminder") }
    expect(task_link).to be_nil

    plan.update!(status: "completed", completed_at: Time.current)
    get event_plan_path(plan)
    active_task_link = response.parsed_body.css("a").find { |link| link["href"]&.include?(active_task.id) && link.text.include?("reminder") }
    expect(active_task_link).to be_nil
  end

  it "invokes source-backed suggestions with explicitly selected context" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    private_note = create(:relationship_note, relationship_profile: profile, private: true)
    allow(EventPlans::Suggest).to receive(:call).and_return([])

    post suggest_event_plan_path(plan), params: {
      event_plan_suggestion: { private_note_ids: [ private_note.id ] }
    }

    expect(EventPlans::Suggest).to have_received(:call).with(
      actor: user,
      event_plan: plan,
      private_note_ids: [ private_note.id.to_s ],
      vault_item_ids: [],
      vault_lease: nil,
      locale: :en
    )
    expect(response).to redirect_to(event_plan_path(plan))
  end

  it "requires vault unlock before selected protected context can be suggested" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    vault_item = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "allowed")

    post suggest_event_plan_path(plan), params: {
      event_plan_suggestion: { vault_item_ids: [ vault_item.id ] }
    }

    expect(response).to redirect_to(relationship_profile_privacy_vault_path(profile))
  end

  it "renders the workspace in both supported locales" do
    plan = create(:event_plan, user:, relationship_profile: profile)

    I18n.with_locale(:es) { get event_plan_path(plan) }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Ruta de planificación", "Sugerir próximos pasos")
  end
end
