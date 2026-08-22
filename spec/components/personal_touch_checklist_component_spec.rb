require "rails_helper"

RSpec.describe PersonalTouchChecklistComponent, type: :component do
  it "renders practical controls, progress, provenance, and no performative score" do
    checklist = create(:personal_touch_checklist)
    create(
      :personal_touch_item,
      personal_touch_checklist: checklist,
      category: "dietary_need",
      origin: "suggested",
      position: 0,
      title: "Plan around Tree nuts: Avoid entirely",
      source_context: [
        {
          "source_type" => "RelationshipPreference",
          "source_id" => SecureRandom.uuid,
          "source_label" => "Tree nuts",
          "certainty" => "confirmed"
        }
      ]
    )
    create(
      :personal_touch_item,
      personal_touch_checklist: checklist,
      origin: "suggested",
      position: 1,
      title: "Keep the gathering small",
      source_context: [
        {
          "source_type" => "RelationshipPreference",
          "source_id" => SecureRandom.uuid,
          "source_label" => "Small gatherings",
          "certainty" => "inferred"
        }
      ]
    )

    render_inline(described_class.new(
      relationship_profile: checklist.relationship_profile,
      moment: checklist.moment,
      checklist:
    ))

    expect(page).to have_css("section[aria-labelledby='personal-touch-checklist-title']")
    expect(page).to have_text("Personal touches")
    expect(page).to have_text("From confirmed preference: Tree nuts")
    expect(page).to have_text("From inferred preference: Small gatherings")
    expect(page).to have_button("Mark Plan around Tree nuts: Avoid entirely complete")
    expect(page).to have_button("Move Plan around Tree nuts: Avoid entirely up", disabled: true)
    expect(page).to have_button("Dismiss Plan around Tree nuts: Avoid entirely")
    expect(page).to have_css("input[placeholder='What would make this feel personal?']", visible: :all)
    expect(page).not_to have_text("care score")
  end

  it "namespaces form controls to the attached checklist" do
    checklist = create(:personal_touch_checklist)

    render_inline(described_class.new(
      relationship_profile: checklist.relationship_profile,
      moment: checklist.moment,
      checklist:
    ))

    title_id = "personal_touch_#{checklist.id}_personal_touch_item_title"
    expect(page.native.at_css("label[for]")["for"]).to eq(title_id)
    expect(page.native.at_css("input[placeholder]")["id"]).to eq(title_id)
  end

  it "renders the empty attachment action in Spanish" do
    plan = create(:event_plan)

    I18n.with_locale(:es) do
      render_inline(described_class.new(
        relationship_profile: plan.relationship_profile,
        moment: plan,
        checklist: nil
      ))
    end

    expect(page).to have_text("Detalles personales")
    expect(page).to have_button("Crear lista")
  end

  it "renders preference certainty in Spanish" do
    checklist = create(:personal_touch_checklist)
    create(
      :personal_touch_item,
      personal_touch_checklist: checklist,
      origin: "suggested",
      title: "Mantén la reunión pequeña",
      source_context: [
        {
          "source_type" => "RelationshipPreference",
          "source_id" => SecureRandom.uuid,
          "source_label" => "Reuniones pequeñas",
          "certainty" => "inferred"
        }
      ]
    )

    I18n.with_locale(:es) do
      render_inline(described_class.new(
        relationship_profile: checklist.relationship_profile,
        moment: checklist.moment,
        checklist:
      ))
    end

    expect(page).to have_text("De preferencia inferida: Reuniones pequeñas")
  end

  it "renders an archived relationship checklist without mutation controls" do
    checklist = create(:personal_touch_checklist)
    item = create(:personal_touch_item, personal_touch_checklist: checklist, title: "Bring the family recipe")
    checklist.relationship_profile.archive!

    render_inline(described_class.new(
      relationship_profile: checklist.relationship_profile,
      moment: checklist.moment,
      checklist:
    ))

    expect(page).to have_text(item.title)
    expect(page).not_to have_button("Mark #{item.title} complete")
    expect(page).not_to have_button("Dismiss #{item.title}")
    expect(page).not_to have_button("Add personal touch")
  end

  it "omits an unattached checklist action for an archived relationship" do
    plan = create(:event_plan)
    plan.relationship_profile.archive!

    render_inline(described_class.new(
      relationship_profile: plan.relationship_profile,
      moment: plan,
      checklist: nil
    ))

    expect(page).not_to have_css("section")
    expect(page).not_to have_button("Create checklist")
  end
end
