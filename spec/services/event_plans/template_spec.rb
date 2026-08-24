require "rails_helper"

RSpec.describe EventPlans::Template do
  it "builds a birthday-specific runway in English and Spanish" do
    english = described_class.for(occasion_type: "birthday", starts_on: Date.new(2026, 9, 12), locale: :en)
    spanish = described_class.for(occasion_type: "birthday", starts_on: Date.new(2026, 9, 12), locale: :es)

    expect(english.pluck(:kind)).to include("gift_idea", "message_draft", "reminder", "backup_step")
    expect(english.pluck(:title)).to include(
      "Choose a birthday gift or personal gesture",
      "Draft a warm birthday message",
      "Prepare a birthday backup plan"
    )
    expect(spanish.pluck(:title)).to include(
      "Elegir un regalo de cumpleaños o gesto personal",
      "Redactar un mensaje de cumpleaños cálido",
      "Preparar un plan alternativo para el cumpleaños"
    )
  end


  it "builds a respectful anniversary runway with effort-adjusted depth in English and Spanish" do
    english = described_class.for(
      occasion_type: "anniversary",
      starts_on: Date.new(2026, 9, 12),
      tone: "understated",
      effort_level: "medium",
      locale: :en
    )
    spanish = described_class.for(
      occasion_type: "anniversary",
      starts_on: Date.new(2026, 9, 12),
      tone: "warm",
      effort_level: "medium",
      locale: :es
    )
    low_effort = described_class.for(
      occasion_type: "anniversary",
      starts_on: Date.new(2026, 9, 12),
      tone: "warm",
      effort_level: "low",
      locale: :en
    )
    high_effort = described_class.for(
      occasion_type: "anniversary",
      starts_on: Date.new(2026, 9, 12),
      tone: "warm",
      effort_level: "high",
      locale: :en
    )

    expect(english.pluck(:kind)).to include("gift_idea", "message_draft", "reminder", "vendor_need")
    expect(english.pluck(:title)).to include(
      "Choose an activity that fits this relationship",
      "Review a reservation before making it",
      "Add one personal touch"
    )
    expect(spanish.pluck(:title)).to include(
      "Elegir una actividad que encaje con esta relación",
      "Revisar una reservación antes de hacerla",
      "Agregar un detalle personal"
    )
    expect(high_effort.find { |task| task[:title] == "Confirm childcare or other practical support" })
      .to include(kind: "task")
    expect(low_effort.length).to be < english.length
  end
end
