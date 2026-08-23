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
      title: "Confirmar la fecha y el formato",
      details: "Decide qué tipo de encuentro o gesto encaja con esta relación."
    )
  end
end
