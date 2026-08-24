require "rails_helper"

RSpec.describe EventPlans::Update do
  it "skips template-copy lookup when the occasion is unchanged" do
    plan = create(:event_plan)

    expect(EventPlans::Template).not_to receive(:for)

    described_class.call(event_plan: plan, attributes: { notes: "Updated constraints" })

    expect(plan.reload.notes).to eq("Updated constraints")
  end

  it "relocalizes untouched template copy when the occasion changes" do
    profile = create(:relationship_profile)
    plan = EventPlans::Create.call(
      user: profile.user,
      relationship_profile: profile,
      attributes: {
        title: "Birthday plan",
        occasion_type: "birthday",
        starts_on: Date.new(2026, 9, 12)
      },
      locale: :en
    )
    customized_task = plan.plan_tasks.find_by!(position: 0)
    customized_task.update!(title: "Keep my wording", details: "Keep my details")

    described_class.call(
      event_plan: plan,
      attributes: { occasion_type: "anniversary" },
      locale: :es
    )

    expect(plan.reload.occasion_type).to eq("anniversary")
    expect(customized_task.reload).to have_attributes(title: "Keep my wording", details: "Keep my details")
    expect(plan.plan_tasks.find_by!(position: 1)).to have_attributes(
      title: "Elegir una actividad que encaje con esta relación",
      details: "Revisa una actividad que encaje con la relación y las circunstancias actuales antes de comprometerte."
    )
    expect(plan.plan_tasks.current.order(:position).pluck(:position)).to eq([ 0, 1, 2, 3, 4, 5, 6, 7, 10 ])
    expect(plan.plan_tasks.current.find_by!(position: 10)).to have_attributes(
      kind: "milestone",
      title: "Revisar el plan para el día del aniversario"
    )
  end

  it "rebases the original anniversary runway after the effort level changes" do
    profile = create(:relationship_profile)
    original_date = Date.new(2026, 9, 12)
    plan = EventPlans::Create.call(
      user: profile.user,
      relationship_profile: profile,
      attributes: {
        title: "Anniversary plan",
        occasion_type: "anniversary",
        starts_on: original_date,
        effort_level: "high"
      }
    )
    customized_due_on = original_date - 1.day
    plan.plan_tasks.find_by!(position: 9).update!(due_on: customized_due_on)

    described_class.call(event_plan: plan, attributes: { effort_level: "low" })
    described_class.call(event_plan: plan, attributes: { starts_on: original_date + 7.days })

    expect(plan.plan_tasks.find_by!(position: 9).due_on).to eq(customized_due_on)
  end

  it "ignores retained high-effort steps when detecting legacy lineage after a downgrade" do
    profile = create(:relationship_profile)
    original_date = Date.new(2026, 9, 12)
    next_date = original_date + 7.days
    plan = EventPlans::Create.call(
      user: profile.user,
      relationship_profile: profile,
      attributes: {
        title: "Anniversary plan",
        occasion_type: "anniversary",
        starts_on: original_date,
        effort_level: "high"
      }
    )
    plan.plan_tasks.find_by!(position: 8).update!(title: "Keep my custom backup step")

    described_class.call(event_plan: plan, attributes: { effort_level: "low" })
    described_class.call(event_plan: plan, attributes: { starts_on: next_date })

    expect(plan.plan_tasks.find_by!(position: 7).due_on).to eq(next_date - 7.days)
    expect(plan.plan_tasks.find_by!(position: 10).due_on).to eq(next_date)
  end

  it "does not relocalize a non-anniversary runway when only planning preferences change" do
    profile = create(:relationship_profile)
    plan = EventPlans::Create.call(
      user: profile.user,
      relationship_profile: profile,
      attributes: {
        title: "Birthday plan",
        occasion_type: "birthday",
        starts_on: Date.new(2026, 9, 12)
      },
      locale: :en
    )
    original_titles = plan.plan_tasks.order(:position).pluck(:title)

    described_class.call(
      event_plan: plan,
      attributes: { tone: "romantic", effort_level: "high" },
      locale: :es
    )

    expect(plan.reload).to have_attributes(tone: "romantic", effort_level: "high")
    expect(plan.plan_tasks.order(:position).pluck(:title)).to eq(original_titles)
  end

  it "clears untouched template deadlines when the plan becomes unscheduled" do
    profile = create(:relationship_profile)
    plan = EventPlans::Create.call(
      user: profile.user,
      relationship_profile: profile,
      attributes: {
        title: "Flexible celebration",
        occasion_type: "custom",
        starts_on: Date.new(2026, 9, 12)
      }
    )
    derived_task, customized_task = plan.plan_tasks.order(:position).first(2)
    customized_due_on = Date.new(2026, 9, 1)
    customized_task.update!(due_on: customized_due_on)

    described_class.call(event_plan: plan, attributes: { starts_on: nil })

    expect(derived_task.reload.due_on).to be_nil
    expect(customized_task.reload.due_on).to eq(customized_due_on)
  end

  it "preserves field-level task customizations while reconciling an occasion change" do
    profile = create(:relationship_profile)
    plan = EventPlans::Create.call(
      user: profile.user,
      relationship_profile: profile,
      attributes: {
        title: "Birthday plan",
        occasion_type: "birthday",
        starts_on: Date.new(2026, 9, 12)
      }
    )
    customized_target = plan.plan_tasks.find_by!(position: 1)
    customized_target.update!(phase: "arrange", kind: "gift_idea", due_on: Date.new(2026, 9, 1))
    customized_removed_position = plan.plan_tasks.find_by!(position: 8)
    customized_removed_position.update!(due_on: Date.new(2026, 9, 2))

    described_class.call(event_plan: plan, attributes: { occasion_type: "anniversary" }, locale: :es)

    expect(customized_target.reload).to have_attributes(
      phase: "arrange",
      kind: "gift_idea",
      due_on: Date.new(2026, 9, 1),
      title: "Elegir una actividad que encaje con esta relación"
    )
    expect(customized_removed_position.reload).to have_attributes(due_on: Date.new(2026, 9, 2))
  end

  it "updates untouched template copy and depth when anniversary preferences change" do
    profile = create(:relationship_profile)
    plan = EventPlans::Create.call(
      user: profile.user,
      relationship_profile: profile,
      attributes: {
        title: "Anniversary plan",
        occasion_type: "anniversary",
        starts_on: Date.new(2026, 9, 12),
        tone: "warm",
        effort_level: "low"
      }
    )
    message_task = plan.plan_tasks.find_by!(position: 5)
    expect(message_task.details).to include("Warm tone")

    described_class.call(
      event_plan: plan,
      attributes: { tone: "romantic", effort_level: "high" }
    )

    expect(message_task.reload.details).to include("Romantic tone")
    expect(plan.plan_tasks.current.order(:position).pluck(:position)).to eq((0..10).to_a)
  end

  it "does not restore a template step the user deleted when effort adds other positions" do
    profile = create(:relationship_profile)
    plan = EventPlans::Create.call(
      user: profile.user,
      relationship_profile: profile,
      attributes: {
        title: "Anniversary plan",
        occasion_type: "anniversary",
        starts_on: Date.new(2026, 9, 12),
        effort_level: "low"
      }
    )
    plan.plan_tasks.find_by!(position: 5).destroy!

    described_class.call(event_plan: plan, attributes: { effort_level: "high" })

    expect(plan.plan_tasks.current.find_by(position: 5)).to be_nil
    expect(plan.plan_tasks.current.order(:position).pluck(:position)).to eq([ 0, 1, 2, 3, 4, 6, 7, 8, 9, 10 ])
  end

  it "adds introduced template steps when a manual task already uses their position" do
    profile = create(:relationship_profile)
    plan = EventPlans::Create.call(
      user: profile.user,
      relationship_profile: profile,
      attributes: { title: "General plan", occasion_type: "custom" }
    )
    manual_task = plan.plan_tasks.create!(
      phase: "arrange",
      kind: "task",
      title: "Keep this authored step",
      position: 9,
      origin: "manual",
      source_context: []
    )

    described_class.call(
      event_plan: plan,
      attributes: { occasion_type: "anniversary", effort_level: "high" }
    )

    expect(manual_task.reload).to have_attributes(position: 9, title: "Keep this authored step")
    expect(plan.plan_tasks.current.where(position: 9).count).to eq(2)
    expect(plan.plan_tasks.current.find_by!(position: 9, origin: "template").title)
      .to eq("Confirm childcare or other practical support")
  end

  it "recognizes and upgrades untouched legacy anniversary templates" do
    profile = create(:relationship_profile)
    starts_on = Date.new(2026, 9, 12)
    plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      occasion_type: "anniversary",
      starts_on:
    )
    EventPlans::Template.for(
      occasion_type: "custom",
      starts_on:,
      locale: :en
    ).each { |attributes| plan.plan_tasks.create!(attributes) }

    described_class.call(
      event_plan: plan,
      attributes: { tone: "romantic", effort_level: "high" }
    )

    expect(plan.plan_tasks.current.find_by!(position: 0).title).to eq("Define what this anniversary should acknowledge")
    expect(plan.plan_tasks.current.find_by!(position: 5).details).to include("Romantic tone")
    expect(plan.plan_tasks.current.order(:position).pluck(:position)).to eq((0..10).to_a)
  end

  it "recognizes and upgrades legacy anniversary templates when every step has customized copy" do
    profile = create(:relationship_profile)
    starts_on = Date.new(2026, 9, 12)
    plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      occasion_type: "anniversary",
      starts_on:
    )
    EventPlans::Template.legacy_anniversary_for(
      starts_on:,
      locale: :en
    ).each do |attributes|
      task = plan.plan_tasks.create!(attributes)
      task.update!(title: "Customized: #{task.title}")
    end

    described_class.call(
      event_plan: plan,
      attributes: { tone: "romantic", effort_level: "high" }
    )

    expect(plan.plan_tasks.current.find_by!(position: 0).title).to start_with("Customized:")
    expect(plan.plan_tasks.current.order(:position).pluck(:position)).to eq((0..10).to_a)
  end

  it "rebases untouched legacy anniversary deadlines with their legacy offsets" do
    profile = create(:relationship_profile)
    previous_starts_on = Date.new(2026, 9, 12)
    next_starts_on = previous_starts_on + 14.days
    plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      occasion_type: "anniversary",
      starts_on: previous_starts_on
    )
    EventPlans::Template.legacy_anniversary_for(
      starts_on: previous_starts_on,
      locale: :en
    ).each { |attributes| plan.plan_tasks.create!(attributes) }

    described_class.call(event_plan: plan, attributes: { starts_on: next_starts_on })

    expected_deadlines = EventPlans::Template.legacy_anniversary_for(
      starts_on: next_starts_on,
      locale: :en
    ).pluck(:due_on)
    expect(plan.plan_tasks.order(:position).pluck(:due_on)).to eq(expected_deadlines)
  end

  it "rebases a legacy anniversary plan whose only remaining task uses a legacy-only position" do
    profile = create(:relationship_profile)
    previous_starts_on = Date.new(2026, 9, 12)
    next_starts_on = previous_starts_on + 14.days
    plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      occasion_type: "anniversary",
      starts_on: previous_starts_on
    )
    legacy_day_of = EventPlans::Template.legacy_anniversary_for(
      starts_on: previous_starts_on,
      locale: :en
    ).find { |attributes| attributes[:position] == 8 }
    task = plan.plan_tasks.create!(legacy_day_of)

    described_class.call(event_plan: plan, attributes: { starts_on: next_starts_on })

    expect(task.reload.due_on).to eq(next_starts_on)
  end
end
