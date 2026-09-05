require "rails_helper"

# == Schema Information
#
# Table name: gift_purchase_plans
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  budget               :decimal(12, 2)
#  constraints          :text
#  currency             :string           default("USD"), not null
#  delivery_status      :string           default("not_started"), not null
#  expected_delivery_on :date
#  follow_up_notes      :text
#  follow_up_on         :date
#  lock_version         :integer          default(0), not null
#  options              :text             not null
#  purchase_by          :date
#  purchase_status      :string           default("planning"), not null
#  shipping_notes       :text
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  gift_id              :uuid             not null
#  plan_task_id         :uuid
#
# Indexes
#
#  index_gift_purchase_plans_on_gift_id       (gift_id) UNIQUE
#  index_gift_purchase_plans_on_plan_task_id  (plan_task_id)
#
# Foreign Keys
#
#  fk_rails_...  (gift_id => gifts.id) ON DELETE => cascade
#  fk_rails_...  (plan_task_id => plan_tasks.id) ON DELETE => nullify
#
RSpec.describe GiftPurchasePlan, type: :model do
  let(:gift) { create(:gift) }
  let(:option) { { "vendor" => "Bookshop", "url" => "https://shop.example/book", "cost" => "24.95", "constraints_checked" => "1" } }

  it "retains encrypted logistics and suggests only a checked option inside the exact budget" do
    plan = described_class.create!(gift:, budget: "25.00", currency: "USD", shipping_notes: "Private doorstep", options: [ option ])
    expect(plan.reload.suggested_option).to eq(option)
    expect(plan.ciphertext_for(:shipping_notes)).not_to include("Private doorstep")
    expect(plan.ciphertext_for(:options)).not_to include("Bookshop")
    plan.budget = "24.94"
    expect(plan.suggested_option).to be_nil
    plan.budget = "25"
    plan.options = [ option.merge("constraints_checked" => "0") ]
    expect(plan.suggested_option).to be_nil
    plan.options = [ option.merge("cost" => "") ]
    expect(plan.suggested_option).to be_nil
  end

  it "rejects malformed and excessive money and unsafe URLs" do
    [ "abc", "1.001", "-1", "Infinity", "10000000000" ].each do |amount|
      expect(described_class.new(gift:, budget: amount)).not_to be_valid
      expect(described_class.new(gift:, options: [ option.merge("cost" => amount) ])).not_to be_valid
    end
    [ "javascript:alert(1)", "//shop.example", "https://user:password@shop.example", "https://" ].each do |url|
      expect(described_class.new(gift:, options: [ option.merge("url" => url) ])).not_to be_valid
    end
  end

  it "validates bounded structured options and independent manual statuses" do
    expect(described_class.new(gift:, options: [ option ] * 4)).not_to be_valid
    expect(described_class.new(gift:, options: "bad")).not_to be_valid
    expect(described_class.new(gift:, options: [ { "url" => "https://shop.example" } ])).not_to be_valid
    expect(described_class.new(gift:, purchase_status: "automatically_paid")).not_to be_valid
    expect(described_class.new(gift:, delivery_status: "unknown")).not_to be_valid
    expect(described_class.new(gift:, purchase_status: "purchased", delivery_status: "shipped")).to be_valid
  end
end
