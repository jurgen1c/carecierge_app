class AddUploadedByUserToActiveStorageBlobs < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_reference :active_storage_blobs,
      :uploaded_by_user,
      type: :uuid,
      foreign_key: false,
      index: false
    add_index :active_storage_blobs, :uploaded_by_user_id, algorithm: :concurrently
    add_foreign_key :active_storage_blobs,
      :users,
      column: :uploaded_by_user_id,
      on_delete: :nullify,
      validate: false
    validate_foreign_key :active_storage_blobs, :users, column: :uploaded_by_user_id
  end

  def down
    remove_foreign_key :active_storage_blobs, column: :uploaded_by_user_id
    remove_index :active_storage_blobs, :uploaded_by_user_id, algorithm: :concurrently
    remove_reference :active_storage_blobs, :uploaded_by_user
  end
end
