require "rails_helper"

RSpec.describe StyleVariantsHelper do
  before do
    stub_const("SpecButtonComponent", Class.new)
    SpecButtonComponent.include StyleVariantsHelper
    SpecButtonComponent.style do
      base { %w[base rounded] }
      defaults { { tone: :primary, disabled: false } }
      variants do
        tone do
          primary { "tone-primary" }
          secondary { |**config| "tone-#{config[:tone]}" }
        end
        disabled do
          yes { "is-disabled" }
          no { "is-enabled" }
        end
        size do
          compact { |**config| "size-#{config[:tone]}" }
        end
      end
      compound(tone: :primary, disabled: true) { |**config| "compound-#{config[:tone]}" }
    end

    stub_const("SpecPrimaryButtonComponent", Class.new(SpecButtonComponent))
    SpecPrimaryButtonComponent.style(:badge) do
      base { "badge-base" }
    end
  end

  it "compiles base styles, defaults, variants, boolean variants, and compounds" do
    component = SpecButtonComponent.new

    expect(component.style(disabled: true, size: :compact)).to eq(
      "base rounded tone-primary is-disabled size-primary compound-primary"
    )
  end

  it "casts false variants and ignores nil overrides" do
    component = SpecButtonComponent.new

    expect(component.style(tone: nil, disabled: false)).to eq("base rounded tone-primary is-enabled")
  end

  it "returns nil for unknown style sets" do
    component = SpecButtonComponent.new

    expect(component.style(:missing)).to be_nil
  end

  it "supports inherited style configuration without mutating the parent" do
    child = SpecPrimaryButtonComponent.new
    parent = SpecButtonComponent.new

    expect(child.style(:badge)).to eq("badge-base")
    expect(child.style(:spec_button)).to eq("base rounded tone-primary is-enabled")
    expect(parent.style(:badge)).to be_nil
  end

  it "supports custom postprocessors" do
    config = StyleVariantsHelper::StyleConfig.new
    config.define(:token) do
      base { %w[a b] }
    end

    config.postprocess_with(->(compiled) { compiled.join("|") })

    expect(config.compile(:token)).to eq("a|b")

    config.postprocess_with { |compiled| compiled.join(",") }

    expect(config.compile(:token)).to eq("a,b")
  end

  it "raises normal method-missing errors when a variant has no block" do
    builder = StyleVariantsHelper::VariantBuilder.new

    expect { builder.public_send(:tone) }.to raise_error(NoMethodError)
  end
end
