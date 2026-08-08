require "rails_helper"

RSpec.describe ExtractedMemoryReviewComponent, type: :component do
  it "renders evidence, uncertainty, and individual review actions" do
    proposal = create(
      :extracted_memory,
      category: "boundary",
      confidence: "inferred",
      title: "Avoid surprise visits",
      source_excerpt: "Surprise visits make me uncomfortable."
    )

    render_inline(described_class.new(extracted_memory: proposal, relationship_profile: proposal.relationship_profile))

    expect(page).to have_text("Boundary")
    expect(page).to have_text("Avoid surprise visits")
    expect(page).to have_text("Surprise visits make me uncomfortable.")
    expect(page).to have_text("This is an interpretation rather than a direct statement")
    expect(page).to have_button("Approve memory")
    expect(page).to have_button("Reject")
    expect(page).to have_field("extracted_memory[corrected_title]", with: "Avoid surprise visits", visible: :all)
  end
end
