require "rails_helper"

RSpec.describe ApplicationPolicy do
  subject(:policy) { described_class.new(user, record) }

  let(:user) { build(:user) }
  let(:record) { Object.new }

  it "denies actions by default" do
    expect(policy.index?).to be(false)
    expect(policy.show?).to be(false)
    expect(policy.create?).to be(false)
    expect(policy.new?).to be(false)
    expect(policy.update?).to be(false)
    expect(policy.edit?).to be(false)
    expect(policy.destroy?).to be(false)
  end

  it "requires subclasses to define scope resolution" do
    scope = described_class::Scope.new(user, User.all)

    expect { scope.resolve }.to raise_error(NoMethodError, "You must define #resolve in ApplicationPolicy::Scope")
  end
end
