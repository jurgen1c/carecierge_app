require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  it "requires sign in before reading operational data" do
    get "/admin"
    expect(response).to redirect_to(new_user_session_path)
  end

  it "forbids ordinary users before querying or auditing" do
    sign_in create(:user)
    expect(AdminDashboard::Query).not_to receive(:new)
    expect { get "/admin" }.not_to change(AuditEvent, :count)
    expect(response).to have_http_status(:forbidden)
  end

  it "audits the admin's access without storing supplied account or relationship context" do
    admin = create(:user, :admin)
    owner = create(:user, email: "private@example.com")
    create(:relationship_profile, user: owner, first_name: "Secret relationship")
    create(:calendar_connection, user: owner, access_token: "secret-token", sync_status: "failed", last_error_code: "provider_error")
    sign_in admin

    expect { get "/admin", params: { account: owner.id, content: "private" } }.to change(AuditEvent, :count).by(1)

    expect(response).to have_http_status(:ok)
    event = AuditEvent.last
    expect(event).to have_attributes(user: admin, actor: admin, action: "admin.dashboard.viewed", source: "support", target: nil, metadata: {})
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.body).to include('name="turbo-cache-control" content="no-cache"')
    expect(response.body).not_to include(owner.email, owner.id, "Secret relationship", "secret-token")
    document = Nokogiri::HTML5.fragment(response.body)
    expect(document.at_css('[data-metric="calendar_failed"]').text).to eq("1")
    expect(document.at_css('a[href="/admin/audit_events"]')).to be_present
    expect(document.at_css('a[href="/admin/feature_flags"]')).to be_present
    expect(document.css('form')).to be_empty
  end

  it "does not read or audit prefetched pages" do
    sign_in create(:user, :admin)
    expect { get "/admin", headers: { "X-Sec-Purpose" => "prefetch" } }.not_to change(AuditEvent, :count)
    expect(response).to have_http_status(:no_content)
  end

  it "fails closed before querying when audit recording fails" do
    sign_in create(:user, :admin)
    allow(AuditEvent).to receive(:record!).and_raise(ActiveRecord::RecordInvalid)
    expect(AdminDashboard::Query).not_to receive(:new)
    expect { get "/admin" }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "renders observed queue counts without job controls" do
    sign_in create(:user, :admin)
    status = instance_double(AdminDashboard::QueueStatus, metrics: { queue_available: true, jobs_failed: 2, workers_recent: 0 })
    allow(AdminDashboard::QueueStatus).to receive(:new).and_return(status)
    get "/admin"
    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML5.fragment(response.body)
    expect(document.at_css('[data-metric="jobs_failed"]').text).to eq("2")
    expect(document.at_css('[data-metric="workers_recent"]').text).to eq("0")
    expect(document.css("form")).to be_empty
  end

  it "renders Spanish and explicit unavailable monitoring" do
    sign_in create(:user, :admin)
    I18n.with_locale(:es) { get "/admin" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Resumen de administración", "No disponible")
    expect(response.body).not_to include("translation missing")
  end
end
