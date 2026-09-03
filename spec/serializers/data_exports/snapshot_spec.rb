require "rails_helper"

RSpec.describe DataExports::Snapshot do
  it "preloads plan tasks for relationship exports" do
    profile = create(:relationship_profile)
    vendor = create(:vendor, user: profile.user)
    2.times do
      plan = create(:event_plan, user: profile.user, relationship_profile: profile)
      create(:plan_task, event_plan: plan)
      backup_plan = create(:backup_plan, user: profile.user, event_plan: plan)
      create(:backup_option, backup_plan:)
      create(:event_plan_vendor, event_plan: plan, vendor:)
    end

    queries = capture_sql do
      described_class.new(user: profile.user, relationship_profile: profile.reload).to_h
    end
    task_queries = queries.select { |query| query.include?('FROM "plan_tasks"') }
    backup_plan_queries = queries.select { |query| query.include?('FROM "backup_plans"') }
    backup_option_queries = queries.select { |query| query.include?('FROM "backup_options"') }
    vendor_queries = queries.select { |query| query.include?('FROM "vendors"') }
    event_plan_vendor_queries = queries.select { |query| query.include?('FROM "event_plan_vendors"') }

    expect(task_queries.length).to eq(1)
    expect(backup_plan_queries.length).to eq(1)
    expect(backup_option_queries.length).to eq(1)
    expect(vendor_queries.length).to eq(1)
    expect(event_plan_vendor_queries.length).to eq(2)
  end

  it "exports attached personal touch checklists and their items" do
    profile = create(:relationship_profile)
    important_date = create(:important_date, relationship_profile: profile)
    checklist = create(
      :personal_touch_checklist,
      relationship_profile: profile,
      event_plan: nil,
      important_date:
    )
    item = create(:personal_touch_item, personal_touch_checklist: checklist, category: "follow_up")

    snapshot = described_class.new(user: profile.user, relationship_profile: profile).to_h
    exported = snapshot.fetch("relationship_profiles").sole.fetch("personal_touch_checklists").sole

    expect(exported).to include("moment_type" => "ImportantDate", "moment_id" => important_date.id)
    expect(exported.fetch("items").sole).to include("id" => item.id, "category" => "follow_up")
  end

  it "exports decrypted vendor quotes with vendor provenance and without ownership or lock fields" do
    quote = create(:vendor_quote, notes: "Private quote note")

    snapshot = described_class.new(user: quote.user, relationship_profile: quote.event_plan.relationship_profile).to_h
    exported = snapshot.dig("relationship_profiles", 0, "event_plans", 0, "vendor_quotes", 0)

    expect(exported).to include(
      "id" => quote.id,
      "amount_cents" => quote.amount_cents,
      "currency" => quote.currency,
      "scope_details" => quote.scope_details,
      "notes" => "Private quote note"
    )
    expect(exported.fetch("vendor")).to include("id" => quote.vendor.id, "name" => quote.vendor.name)
    expect(exported).not_to have_key("user_id")
    expect(exported).not_to have_key("event_plan_id")
    expect(exported).not_to have_key("vendor_id")
    expect(exported).not_to have_key("lock_version")
  end

  it "keeps sensitive backup source plaintext behind the sensitive export gate" do
    profile = create(:relationship_profile)
    plan = create(:event_plan, user: profile.user, relationship_profile: profile)
    backup_plan = create(
      :backup_plan,
      user: profile.user,
      event_plan: plan,
      include_vault_context: true,
      source_context: [
        {
          "id" => "vault:protected-source",
          "kind" => "vault",
          "content" => "A protected family detail",
          "label" => "Privacy vault",
          "certainty" => "confirmed",
          "sensitive" => true
        }
      ]
    )

    ordinary_snapshot = described_class.new(user: profile.user, relationship_profile: profile).to_h
    sensitive_snapshot = described_class.new(
      user: profile.user,
      relationship_profile: profile,
      include_sensitive: true
    ).to_h

    ordinary_source = ordinary_snapshot.dig("relationship_profiles", 0, "event_plans", 0, "backup_plans", 0, "source_context", 0)
    sensitive_source = sensitive_snapshot.dig("relationship_profiles", 0, "event_plans", 0, "backup_plans", 0, "source_context", 0)
    exported_backup_plan = ordinary_snapshot.dig("relationship_profiles", 0, "event_plans", 0, "backup_plans", 0)
    expect(ordinary_source).to include("id" => "vault:protected-source", "sensitive" => true)
    expect(ordinary_source).not_to have_key("content")
    expect(sensitive_source).to include("content" => backup_plan.source_context.sole.fetch("content"))
    expect(exported_backup_plan).not_to have_key("context_fingerprint")
  end

  private

  def capture_sql
    queries = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached]

      queries << payload[:sql]
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
    queries
  end
end
