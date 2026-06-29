class AddRelationshipProfileIntegrityConstraints < ActiveRecord::Migration[8.1]
  def change
    # Kept as a no-op compatibility migration for local databases that ran the
    # earlier relationship-type foreign-key migration before relationship profiles
    # were created directly with STI-backed type data.
  end
end
