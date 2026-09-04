require "rails_helper"

RSpec.describe CalendarConnectionComponent, type: :component do
  it "renders localized accessible sync controls and an explicit revocation consequence" do
    connection = build(:calendar_connection, sync_types: %w[important_dates reminders], sync_status: "failed", last_error_code: "provider_unavailable")

    I18n.with_locale(:es) do
      render_inline(described_class.new(connection:, provider_available: true))
    end

    expect(page).to have_css("input[role='switch'][aria-label='Fechas importantes'][checked]")
    expect(page).to have_css("input[role='switch'][aria-label='Recordatorios'][checked]")
    expect(page).to have_button("Reintentar sincronización")
    expect(page).to have_button("Desconectar Google Calendar")
    expect(page).to have_text("Los eventos ya creados permanecerán en Google Calendar")
    settings_form = page.all("form[action='#{Rails.application.routes.url_helpers.calendar_connection_path}']")
      .find { |form| form["data-turbo-confirm"].present? }
    expect(settings_form["data-turbo-confirm"]).to include("elimina de Google Calendar")
  end

  it "renders a provider availability state without a dead connect control" do
    render_inline(described_class.new(connection: nil, provider_available: false))

    expect(page).to have_text("Google Calendar is not available yet")
    expect(page).not_to have_link("Connect Google Calendar")
  end

  it "offers a direct reconnect action when authorization is required" do
    connection = build(:calendar_connection, sync_status: "action_required", last_error_code: "authorization_required")

    render_inline(described_class.new(connection:, provider_available: true))

    link = page.find_link("Reconnect Google Calendar", href: Rails.application.routes.url_helpers.new_calendar_connection_path)
    expect(link["data-turbo"]).to eq("false")
    expect(page).not_to have_button("Retry sync")
  end

  it "uses a full-page navigation to launch external authorization" do
    render_inline(described_class.new(connection: nil, provider_available: true))

    link = page.find_link("Connect Google Calendar", href: Rails.application.routes.url_helpers.new_calendar_connection_path)
    expect(link["data-turbo"]).to eq("false")
  end

  it "shows unresolved callback cleanup instead of a connect action" do
    render_inline(described_class.new(connection: nil, provider_available: true, credential_revocation_pending: true))

    expect(page).to have_text("Calendar access cleanup is still in progress")
    expect(page).not_to have_link("Connect Google Calendar")
  end

  it "links permission failures to calendar automation settings" do
    connection = build(:calendar_connection, sync_status: "failed", last_error_code: "calendar_permission_required")

    render_inline(described_class.new(connection:, provider_available: true))

    expect(page).to have_link(
      "Review calendar permission",
      href: Rails.application.routes.url_helpers.edit_automation_permissions_path(capability: "access_calendar")
    )
    expect(page).to have_button("Retry sync")
  end

  it "explains that failed revocation leaves provider access active" do
    connection = build(:calendar_connection, sync_status: "failed", last_error_code: "revocation_failed")

    render_inline(described_class.new(connection:, provider_available: true))

    expect(page).to have_text("Calendar access is still active")
    expect(page).not_to have_button("Retry sync")
    expect(page).not_to have_link("Connect Google Calendar")
    expect(page).not_to have_link("Reconnect Google Calendar")
  end

  it "offers owner-triggered recovery after a permanent sync failure" do
    connection = build(:calendar_connection, sync_status: "failed", last_error_code: "provider_rejected")

    render_inline(described_class.new(connection:, provider_available: true))

    expect(page).to have_button("Retry sync")
  end

  it "uses semantic design tokens for every status" do
    CalendarConnection::SYNC_STATUSES.each do |sync_status|
      connection = build(:calendar_connection, sync_status:)
      connection.sync_lease_token = SecureRandom.uuid if sync_status == "syncing"
      connection.sync_lease_expires_at = 1.minute.from_now if sync_status == "syncing"
      render_inline(described_class.new(connection:, provider_available: true))

      badge = page.find("span", text: I18n.t("calendar_connections.statuses.#{sync_status}"), exact_text: true)
      expect(badge[:class]).not_to match(/(?:emerald|stone|red)-\d+/)
    end
  end
end
