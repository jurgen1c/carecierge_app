require "rails_helper"

RSpec.describe VendorAccountProfileComponent, type: :component do
  it "associates labels, hints and errors and preserves explicit focus styles" do
    account = build(:vendor_account, business_name: "x" * 201)
    account.valid?
    render_inline(described_class.new(account:, editable: true))
    expect(page).to have_css('label[for="vendor_account_business_name"]', text: "Business name")
    expect(page).to have_css('input#vendor_account_business_name[aria-invalid="true"][aria-describedby="business_name-hint business_name-errors"]')
    expect(page).to have_css('a[href="#vendor_account_business_name"]')
    expect(page).to have_css('input#vendor_account_business_name[class*="focus-visible:outline"]')
    expect(page).to have_css('fieldset legend', text: "Business categories")
  end

  it "renders escaped read-only business content in Spanish" do
    I18n.with_locale(:es) do
      render_inline(described_class.new(account: build(:vendor_account, offerings: "<script>alert(1)</script>")))
      expect(page).to have_content("Productos y servicios")
      expect(page).to have_no_css("script")
      expect(page).to have_no_css("form")
    end
  end

  it "links category validation errors to the focusable category group" do
    account = build(:vendor_account, status: "submitted", categories: [])
    account.valid?
    render_inline(described_class.new(account:, editable: true))
    expect(page).to have_css('a[href="#vendor_account_categories"]', text: account.errors.full_messages_for(:categories).first)
    expect(page).to have_css('fieldset#vendor_account_categories[tabindex="-1"][aria-invalid="true"][aria-describedby="categories-hint categories-errors"]')
  end
end
