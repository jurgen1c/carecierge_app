class AddHandedOffAtToDigestDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_column :digest_deliveries, :handed_off_at, :datetime
  end
end
