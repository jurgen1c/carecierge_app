class AddMailboxIdentityToMessagingConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :messaging_connections, :mailbox_email, :text
  end
end
