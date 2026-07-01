class AddCaseInsensitiveRelationshipIndexes < ActiveRecord::Migration[8.1]
  def change
    # Kept as a no-op compatibility migration for local databases that ran the
    # earlier combined relationship-profile migration before the tables were split.
  end
end
