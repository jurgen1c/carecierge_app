require "rails_helper"

RSpec.describe "Approval queue", type: :request do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:, first_name: "Jamie") }
  let(:recap) { create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review", title: "Dinner recap") }
  let!(:proposal) do
    create(
      :extracted_memory,
      relationship_profile: profile,
      conversation_recap: recap,
      title: "Prefers vegetarian restaurants",
      body: "Vegetarian restaurants are usually preferred.",
      source_excerpt: "I usually choose vegetarian restaurants.",
      confidence: "medium"
    )
  end

  before { sign_in user }

  it "shows one owner-scoped place to understand consequences and decide" do
    foreign_profile = create(:relationship_profile)
    create(:extracted_memory, relationship_profile: foreign_profile, conversation_recap: create(:conversation_recap, relationship_profile: foreign_profile), title: "Foreign private memory")

    get approvals_path

    expect(response).to have_http_status(:ok)
    expect(response.headers.fetch("Cache-Control")).to include("no-store")
    expect(response.body).to include(
      "Approval queue",
      "Prefers vegetarian restaurants",
      "Understand the source",
      "Review the consequence",
      "Decide",
      "I usually choose vegetarian restaurants.",
      "What will happen",
      "What will not happen",
      "Approve",
      "Edit",
      "Reject",
      "Keep for later",
      "Dismiss"
    )
    expect(response.body).not_to include("Foreign private memory", "Translation missing")
  end

  it "places the selected approval before the queue rail for narrow layouts" do
    get approvals_path

    document = Nokogiri::HTML(response.body)
    layout = document.at_css("[data-approval-queue-layout]")

    expect(layout.element_children.first["data-approval-selected-item"]).to eq("true")
    expect(layout.element_children.last.name).to eq("aside")
  end

  it "renders the queue after removing an open envelope whose source is missing" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    orphaned_request = create(
      :approval_request,
      user:,
      subject: memory,
      kind: "memory_record",
      action_key: "approve_high_impact_memory",
      risk_level: "high",
      confidence: "low"
    )
    memory.delete

    get approvals_path

    expect(response).to have_http_status(:ok)
    expect(ApprovalRequest.exists?(orphaned_request.id)).to be(false)
  end

  it "keeps the complete queue localized in Spanish" do
    I18n.with_locale(:es) { get approvals_path }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Aprobaciones", "Comprende la fuente", "Revisa la consecuencia", "Decide")
    expect(response.body).not_to include("Translation missing")
  end

  it "renders queue rail timestamps in the owner's time zone" do
    create(:notification_preference, user:, time_zone: "America/Costa_Rica")
    queued_at = Time.utc(2026, 8, 29, 2, 30)
    zone = ActiveSupport::TimeZone["America/Costa_Rica"]

    Timecop.freeze(Time.utc(2026, 8, 29, 12)) do
      ApprovalQueue::Synchronize.call(user:)
      user.approval_requests.find_by!(subject: proposal).update_column(:created_at, queued_at)

      get approvals_path
    end

    expect(response.body).to include(I18n.l(queued_at.in_time_zone(zone), format: :approval))
    expect(response.body).not_to include(I18n.l(queued_at, format: :approval))
  end

  it "preloads canonical memory vault state for completed extracted-memory rows" do
    3.times do |index|
      memory = create(
        :memory_record,
        relationship_profile: profile,
        source: "user_confirmed",
        confidence: "confirmed"
      )
      reviewed_proposal = create(
        :extracted_memory,
        relationship_profile: profile,
        conversation_recap: recap,
        canonical_memory_record: memory,
        status: "approved",
        title: "Reviewed proposal #{index}"
      )
      create(
        :approval_request,
        user:,
        subject: reviewed_proposal,
        status: "approved",
        decided_at: Time.current
      )
    end

    queries = capture_sql { get approvals_path(status: "completed") }
    canonical_memory_batch_queries = queries.grep(
      /FROM "memory_records" WHERE "memory_records"\."id" IN \(/
    )
    canonical_memory_singular_queries = queries.grep(
      /FROM "memory_records" WHERE "memory_records"\."id" = .* LIMIT/
    )
    vault_state_batch_queries = queries.grep(
      /FROM "privacy_vault_items" WHERE .*"privacy_vault_items"\."protectable_id" IN \(/
    )
    vault_state_singular_queries = queries.grep(
      /FROM "privacy_vault_items" WHERE .*"privacy_vault_items"\."protectable_id" = .* LIMIT/
    )

    expect(canonical_memory_batch_queries.size).to eq(1)
    expect(vault_state_batch_queries.size).to eq(1)
    expect(canonical_memory_singular_queries.size).to be <= 1
    expect(vault_state_singular_queries.size).to be <= 1
  end

  it "updates the selected underlying object through an owner-scoped decision" do
    ApprovalQueue::Synchronize.call(user:)
    request_record = user.approval_requests.find_by!(subject: proposal)

    patch approval_path(request_record), params: {
      approval_request: { decision: "approve", lock_version: request_record.lock_version }
    }

    expect(response).to redirect_to(approvals_path(status: "pending"))
    expect(request_record.reload.status).to eq("approved")
    expect(proposal.reload.status).to eq("approved")
  end

  it "keeps a deferred decision visible in the deferred tab" do
    ApprovalQueue::Synchronize.call(user:)
    request_record = user.approval_requests.find_by!(subject: proposal)

    Timecop.freeze(Time.zone.local(2026, 9, 1, 9)) do
      patch approval_path(request_record), params: {
        approval_request: {
          decision: "defer",
          lock_version: request_record.lock_version,
          deferred_until: 1.day.from_now.strftime("%Y-%m-%dT%H:%M")
        }
      }

      expect(response).to redirect_to(approvals_path(status: "deferred", id: request_record.id))
      expect(request_record.reload.status).to eq("deferred")

      follow_redirect!

      expect(Nokogiri::HTML(response.body).at_css("#approval-item-title").text).to include(proposal.title)
    end
  end

  it "returns not found for another owner's request" do
    foreign_request = create(:approval_request)

    patch approval_path(foreign_request), params: {
      approval_request: { decision: "dismiss", lock_version: foreign_request.lock_version }
    }

    expect(response).to have_http_status(:not_found)
    expect(foreign_request.reload.status).to eq("pending")
  end

  it "handles a missing optimistic lock as invalid input" do
    ApprovalQueue::Synchronize.call(user:)
    request_record = user.approval_requests.find_by!(subject: proposal)

    patch approval_path(request_record), params: {
      approval_request: { decision: "approve" }
    }

    expect(response).to redirect_to(approvals_path(status: "pending", id: request_record.id))
    expect(request_record.reload.status).to eq("pending")
    expect(proposal.reload.status).to eq("pending")
  end

  it "preserves the selected page and form mode when a decision fails" do
    ApprovalQueue::Synchronize.call(user:)
    request_record = user.approval_requests.find_by!(subject: proposal)

    patch approval_path(request_record, page: 2, mode: "edit"), params: {
      approval_request: { decision: "edit", lock_version: request_record.lock_version }
    }

    expect(response).to redirect_to(
      approvals_path(status: "pending", page: 2, id: request_record.id, mode: "edit")
    )
    expect(request_record.reload.status).to eq("pending")
    expect(proposal.reload.status).to eq("pending")
  end

  it "preserves pagination when selecting a request" do
    26.times do |index|
      page_profile = create(:relationship_profile, user:, preferred_name: "Person #{index}")
      create(:memory_record, relationship_profile: page_profile, source: "ai_inferred", confidence: "low")
    end

    get approvals_path(page: 2)

    selected_link = Nokogiri::HTML(response.body).at_css("aside a[href*='id=']")
    query = Rack::Utils.parse_query(URI.parse(selected_link["href"]).query)
    expect(query).to include("page" => "2", "status" => "pending")

    proposal_request = user.approval_requests.find_by!(subject: proposal)
    get approvals_path(page: 1, id: proposal_request.id)

    selected_title = Nokogiri::HTML(response.body).at_css("#approval-item-title")
    expect(selected_title.text).to include(proposal.title)

    get approvals_path(page: 2, id: proposal_request.id)

    document = Nokogiri::HTML(response.body)
    edit_link = document.at_xpath("//a[normalize-space()='Edit']")
    defer_link = document.at_xpath("//a[normalize-space()='Keep for later']")
    expect(Rack::Utils.parse_query(URI.parse(edit_link["href"]).query)).to include("page" => "2")
    expect(Rack::Utils.parse_query(URI.parse(defer_link["href"]).query)).to include("page" => "2")

    get edit_link["href"]

    edit_form = Nokogiri::HTML(response.body).at_css("form[action*='/approvals/#{proposal_request.id}']")
    expect(Rack::Utils.parse_query(URI.parse(edit_form["action"]).query)).to include("page" => "2", "mode" => "edit")
  end

  def capture_sql
    queries = []
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      next if payload[:cached] || payload[:name] == "SCHEMA"

      queries << payload[:sql]
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
    queries
  end
end
