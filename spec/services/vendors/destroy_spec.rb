require "rails_helper"

RSpec.describe Vendors::Destroy do
  it "locks the owner before the vendor and deletes the saved record" do
    vendor = create(:vendor)

    expect(vendor.user).to receive(:with_lock).with("FOR NO KEY UPDATE").ordered.and_call_original
    expect(vendor).to receive(:lock!).ordered.and_call_original

    expect do
      described_class.call(vendor:)
    end.to change(Vendor, :count).by(-1)
  end

  it "preserves vendors that still hold user-authored shortlist comparisons" do
    option = create(:vendor_option, notes: "Keep this private comparison note")
    vendor = option.vendor

    expect do
      described_class.call(vendor:)
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(vendor.errors[:base]).to include("Remove this vendor from every comparison before deleting it")
    expect(option.reload.notes).to eq("Keep this private comparison note")
  end
end
