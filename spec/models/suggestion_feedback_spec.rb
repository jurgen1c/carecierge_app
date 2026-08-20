# == Schema Information
#
# Table name: suggestion_feedbacks
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  acted_at                :datetime
#  dismissed_at            :datetime
#  feedback                :string
#  fingerprint             :string           not null
#  saved_at                :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_dismissed_at_d046df9002  (relationship_profile_id,dismissed_at)
#  index_suggestion_feedbacks_on_relationship_profile_id   (relationship_profile_id)
#  index_suggestion_feedbacks_on_user_id                   (user_id)
#  index_suggestion_feedbacks_on_user_id_and_fingerprint   (user_id,fingerprint) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe SuggestionFeedback do
  it "requires the feedback owner to own the relationship profile" do
    feedback = build(
      described_class.model_name.singular.to_sym,
      user: create(:user),
      relationship_profile: create(:relationship_profile)
    )

    expect(feedback).not_to be_valid
    expect(feedback.errors[:relationship_profile]).to be_present
  end

  it "tracks feedback, save, dismissal, and completed action state" do
    feedback = create(described_class.model_name.singular.to_sym)

    Timecop.freeze(Time.zone.local(2026, 8, 8, 10, 30)) do
      feedback.record_feedback!("helpful")
      expect(feedback).not_to be_hidden

      feedback.save_for_later!
      expect(feedback).to be_saved_for_later
      expect(feedback.saved_at).to eq(Time.current)
      expect(feedback).not_to be_hidden

      feedback.dismiss!
      expect(feedback).to be_hidden
      expect(feedback.dismissed_at).to eq(Time.current)
    end

    feedback.update!(dismissed_at: nil)

    Timecop.freeze(Time.zone.local(2026, 8, 8, 11, 0)) do
      feedback.mark_acted!
      expect(feedback).to be_hidden
      expect(feedback.acted_at).to eq(Time.current)
    end
  end

  it "rejects unsupported feedback values" do
    feedback = build(described_class.model_name.singular.to_sym, feedback: "maybe")

    expect(feedback).not_to be_valid
    expect(feedback.errors[:feedback]).to be_present
  end
end
