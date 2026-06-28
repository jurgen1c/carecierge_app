class AddRelationshipProfileIntegrityConstraints < ActiveRecord::Migration[8.1]
  def change
    # Kept as a no-op compatibility migration for local databases that ran the
    # earlier relationship-type foreign-key migration before the model was folded
    # into RelationshipProfile as profile-owned relationship_type_name data.
  end
end
