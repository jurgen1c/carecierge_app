class AddEmailDeliveredAtToDigestDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_column :digest_deliveries, :email_delivered_at, :datetime
  end
end
