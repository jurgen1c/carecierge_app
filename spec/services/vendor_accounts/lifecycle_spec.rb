require "rails_helper"

RSpec.describe "Vendor account lifecycle", type: :service do
  let(:owner) { create(:user) }
  let(:admin) { create(:user, admin: true) }
  let(:details) do
    { business_name: "Orchid Studio", categories: [ "florist" ], service_area: "San José, Heredia",
      offerings: "Seasonal bouquets for celebrations", contact_channels: "Business phone: +506 2222 2222",
      source_url: "https://orchid.example.com", provenance: "Business owner supplied; established in 2020" }
  end

  def enroll
    VendorAccounts::Enroll.call(user: owner)
  end

  def save(account, attributes = details)
    VendorAccounts::Save.call(user: owner, account:, attributes:, version: account.lock_version.to_s)
  end

  def transition(account, to:, actor: owner, reason: nil, version: account.lock_version.to_s)
    VendorAccounts::Transition.call(user: actor, account:, to:, reason:, version:)
  end

  it "resumes one draft and rejects duplicate persistence" do
    account = enroll
    expect(enroll).to eq(account)
    expect(account).to have_attributes(status: "draft", user: owner)
    expect(VendorAccount.new(user: owner)).not_to be_valid
  end

  it "requires a confirmed identity" do
    owner.update_column(:confirmed_at, nil)
    expect { enroll }.to raise_error(Pundit::NotAuthorizedError)
  end

  it "rejects incomplete submission without evidence or publication" do
    account = enroll
    expect { transition(account, to: "submitted") }.to raise_error(ActiveRecord::RecordInvalid)
    expect(account.reload.status).to eq("draft")
    expect(account.reviews).to be_empty
    expect(account.marketplace_listing).to be_nil
  end

  it "publishes only the reviewed profile and withdraws approved edits" do
    account = enroll
    save(account)
    transition(account, to: "submitted")
    expect(MarketplaceListing.published).to be_empty
    transition(account, to: "approved", actor: admin)
    listing = account.reload.marketplace_listing
    expect(listing).to have_attributes(published: true, name: "Orchid Studio")
    expect(account.reviews.order(:created_at).last).to have_attributes(actor: admin, to_status: "approved")
    expect(account.reviews.order(:created_at, :id).last.profile_snapshot["offerings"]).to eq(details[:offerings])
    save(account, offerings: "Unreviewed change")
    expect(listing.reload).not_to be_published
    expect(account.status).to eq("draft")
    expect(listing.curated_summary).to eq(details[:offerings])
  end

  it "rejects with a reason, permits revision, and keeps suspension enforced" do
    account = enroll
    save(account)
    transition(account, to: "submitted")
    expect { transition(account, to: "rejected", actor: admin) }.to raise_error(ActiveRecord::RecordInvalid)
    account.reload
    transition(account, to: "rejected", actor: admin, reason: "Please clarify service coverage")
    expect(account.reviews.order(:created_at, :id).last.reason).to eq("Please clarify service coverage")
    save(account)
    transition(account, to: "submitted")
    transition(account, to: "approved", actor: admin)
    transition(account, to: "suspended", actor: admin, reason: "Business details require verification")
    save(account, offerings: "Updated offering")
    expect(account.status).to eq("suspended")
    expect { transition(account, to: "submitted") }.to raise_error(ActiveRecord::RecordInvalid)
    expect(account.reload.marketplace_listing).not_to be_published
  end

  it "rejects stale edits and a stale moderator decision after a new submission" do
    account = enroll
    save(account)
    transition(account, to: "submitted")
    old_version = account.lock_version.to_s
    save(account, offerings: "Revised offer")
    transition(account, to: "submitted")
    expect { transition(account, to: "approved", actor: admin, version: old_version) }.to raise_error(ActiveRecord::StaleObjectError)
    expect { VendorAccounts::Save.call(user: owner, account:, attributes: details, version: old_version) }.to raise_error(ActiveRecord::StaleObjectError)
    expect { transition(account, to: "approved", actor: admin, version: nil) }.to raise_error(ActiveRecord::StaleObjectError)
    expect(account.reload.status).to eq("submitted")
  end

  it "enforces ownership and moderator authority inside operations" do
    account = enroll
    stranger = create(:user)
    expect { VendorAccounts::Save.call(user: stranger, account:, attributes: details, version: "0") }.to raise_error(Pundit::NotAuthorizedError)
    expect { transition(account, to: "approved") }.to raise_error(Pundit::NotAuthorizedError)
    expect { transition(account, to: "submitted", actor: stranger) }.to raise_error(Pundit::NotAuthorizedError)
  end

  it "makes review evidence encrypted and append-only, and fails closed on evidence failure" do
    account = enroll
    save(account)
    transition(account, to: "submitted")
    review = account.reviews.sole
    expect(review.attributes_before_type_cast["profile_snapshot"]).not_to include("Orchid Studio")
    expect { review.update!(to_status: "approved") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { review.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
    allow_any_instance_of(VendorAccountReview).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)
    expect { transition(account, to: "approved", actor: admin) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(account.reload.status).to eq("submitted")
    expect(MarketplaceListing.published).to be_empty
  end
end
