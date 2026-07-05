require "rails_helper"

RSpec.describe ImportantDatePolicy do
  describe described_class::Scope do
    it "returns no records without a signed-in user" do
      create(:important_date)

      resolved = described_class.new(nil, ImportantDate.all).resolve

      expect(resolved).to be_empty
    end

    it "scopes records to the signed-in relationship profile owner" do
      user = create(:user)
      visible_profile = create(:relationship_profile, user:)
      visible = create(:important_date, relationship_profile: visible_profile)
      hidden = create(:important_date)

      resolved = described_class.new(user, ImportantDate.all).resolve

      expect(resolved).to include(visible)
      expect(resolved).not_to include(hidden)
    end
  end
end
