require "rails_helper"

RSpec.describe Commitments::Save do
  describe ".call" do
    let(:commitment) { build(:commitment) }

    it "requires exactly one operation" do
      expect { described_class.call(commitment) }
        .to raise_error(ArgumentError, "provide exactly one of attributes or event")

      expect { described_class.call(commitment, attributes: { title: "Updated" }, event: :complete) }
        .to raise_error(ArgumentError, "provide exactly one of attributes or event")
    end

    it "rejects unsupported lifecycle events" do
      expect { described_class.call(commitment, event: :archive) }
        .to raise_error(ArgumentError, "unsupported commitment event: archive")
    end
  end
end
