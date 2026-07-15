require "rails_helper"
require Rails.root.join("db/data/20260715031947_backfill_interactions_from_relationship_sources")

RSpec.describe BackfillInteractionsFromRelationshipSources do
  describe "#up" do
    it "backfills past sources while leaving legacy future sources untouched" do
      database_now = ApplicationRecord.connection.select_value("SELECT CURRENT_TIMESTAMP").in_time_zone
      past_recap = create(:conversation_recap, occurred_at: database_now - 1.minute)
      future_recap = create(:conversation_recap, occurred_at: database_now - 1.minute)
      past_note = create(:mood_note, observed_at: database_now - 1.minute)
      future_note = create(:mood_note, observed_at: database_now - 1.minute)
      future_recap.update_column(:occurred_at, database_now + 1.minute)
      future_note.update_column(:observed_at, database_now + 1.minute)

      described_class.new.up

      expect(Interaction.where(source: [ past_recap, past_note ])).to have_attributes(size: 2)
      expect(Interaction.where(source: [ future_recap, future_note ])).to be_empty
    end
  end
end
