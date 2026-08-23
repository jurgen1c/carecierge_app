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
end
