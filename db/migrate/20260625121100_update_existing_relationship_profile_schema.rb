class UpdateExistingRelationshipProfileSchema < ActiveRecord::Migration[8.1]
  def change
    # No-op: relationship profiles are created directly in the current schema
    # with namespaced STI type data, discard state, and friendly slugs.
  end
end
