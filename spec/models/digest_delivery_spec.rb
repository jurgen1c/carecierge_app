# == Schema Information
#
# Table name: digest_deliveries
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  channel            :string           not null
#  dispatched_at      :datetime
#  email_delivered_at :datetime
#  enqueued_at        :datetime
#  error_message      :text
#  handed_off_at      :datetime
#  mode               :string           not null
#  scheduled_for      :datetime         not null
#  status             :string           default("pending"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  user_id            :uuid             not null
#
# Indexes
#
#  index_digest_deliveries_on_recoverable_lease    (enqueued_at) WHERE ((status)::text = ANY ((ARRAY['pending'::character varying, 'dispatching'::character varying])::text[]))
#  index_digest_deliveries_on_user_and_occurrence  (user_id,scheduled_for) UNIQUE
#  index_digest_deliveries_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe DigestDelivery, type: :model do
  it "prevents duplicate user occurrences" do
    delivery = create(:digest_delivery)

    duplicate = build(:digest_delivery, user: delivery.user, scheduled_for: delivery.scheduled_for)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:scheduled_for]).to be_present
  end

  it "destroys its Noticed events with the delivery" do
    delivery = create(:digest_delivery, channel: "in_app")
    event = DigestInAppNotifier.with(record: delivery, mode: delivery.mode)
      .deliver(delivery.user, enqueue_job: false)

    expect { delivery.destroy! }.to change(Noticed::Event, :count).by(-1)
    expect(Noticed::Event.exists?(event.id)).to be(false)
  end
end
