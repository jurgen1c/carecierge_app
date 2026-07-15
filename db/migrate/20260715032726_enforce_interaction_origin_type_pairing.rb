class EnforceInteractionOriginTypePairing < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :interactions,
      "(origin = 'manual' AND interaction_type IN ('call', 'message', 'in_person', 'video', 'other')) OR " \
      "(origin = 'derived' AND interaction_type IN ('conversation_recap', 'mood_note'))",
      name: "interactions_origin_matches_type"
  end
end
