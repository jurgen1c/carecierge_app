require "rails_helper"

RSpec.describe RelationshipMemorySearch::SearchQuery do
  it "requires an explicit owner-scoped relationship relation" do
    expect { described_class.new(params: ActionController::Parameters.new) }.to raise_error(ArgumentError)
  end

  it "normalizes matches from every supported relationship memory source" do
    user = create(:user)
    profile = create(:relationship_profile, user:, first_name: "Ana")
    matching_profile = create(:relationship_profile, user:, first_name: "Alpine", last_name: nil)
    create(:relationship_note, relationship_profile: profile, body: "Planning an alpine weekend.")
    create(:relationship_preference, relationship_profile: profile, key: "Trips", value: "Alpine trails")
    create(:timeline_entry, relationship_profile: profile, title: "Alpine planning", body: "Compared trail routes")
    create(:interaction, relationship_profile: profile, notes: "Talked about alpine hikes")
    create(:commitment, relationship_profile: profile, title: "Book alpine cabin")
    create(:gift, relationship_profile: profile, name: "Alpine guidebook")
    create(:important_date, relationship_profile: profile, title: "Alpine trip")

    results = resolve(user:, memory_query: "alpine")

    expect(results.map(&:source_type)).to contain_exactly(
      "profiles",
      "notes",
      "preferences",
      "timeline",
      "timeline",
      "commitments",
      "gifts",
      "important_dates"
    )
    expect(results.find { |result| result.source_record.id == matching_profile.id }.title).to eq("Alpine")
    expect(results.reject { |result| result.source_record.id == matching_profile.id }.map { |result| result.relationship_profile.id }).to all(eq(profile.id))
    expect(results).to all(have_attributes(title: be_present, excerpt: be_present))
  end

  it "accepts the all-sources value submitted by the search form" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    gift = create(:gift, relationship_profile: profile, name: "Alpine guidebook")

    results = resolve(user:, memory_query: "alpine", source: "all")

    expect(results.map(&:source_record)).to include(gift)
  end

  it "keeps results inside the supplied owner scope and excludes archived and vault-protected records by default" do
    user = create(:user)
    visible_profile = create(:relationship_profile, user:, first_name: "Visible")
    archived_profile = create(:relationship_profile, user:, first_name: "Archived", discarded_at: Time.current)
    hidden_profile = create(:relationship_profile, first_name: "Hidden")
    visible_note = create(:relationship_note, relationship_profile: visible_profile, body: "Secret garden plans")
    create(:relationship_note, relationship_profile: archived_profile, body: "Secret garden archived")
    create(:relationship_note, relationship_profile: hidden_profile, body: "Secret garden hidden")
    protected_note = create(:relationship_note, relationship_profile: visible_profile, body: "Secret garden protected")
    create(
      :privacy_vault_item,
      relationship_profile: visible_profile,
      protectable: protected_note,
      payload: { "title_key" => "general_note", "body" => "Secret garden protected" }
    )

    results = resolve(user:, memory_query: "secret garden")

    expect(results.map(&:source_record)).to contain_exactly(visible_note)
  end

  it "matches visible rich-text phrases split by formatting markup" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(
      :relationship_note,
      relationship_profile: profile,
      body: "<p>Alpine <strong>weekend</strong></p>"
    )

    results = resolve(user:, memory_query: "alpine weekend", source: "notes")

    expect(results.map(&:source_record)).to contain_exactly(note)
  end

  it "matches visible rich-text phrases containing HTML-escaped characters" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(:relationship_note, relationship_profile: profile, body: "Research & development")

    results = resolve(user:, memory_query: "research & development", source: "notes")

    expect(results.map(&:source_record)).to contain_exactly(note)
  end

  it "decodes visible rich-text entities exactly once" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(:relationship_note, relationship_profile: profile, body: "Use &amp;lt; literally")

    visible_results = resolve(user:, memory_query: "&lt;", source: "notes")
    decoded_results = resolve(user:, memory_query: "<", source: "notes")

    expect(visible_results.map(&:source_record)).to contain_exactly(note)
    expect(decoded_results.map(&:source_record)).not_to include(note)
  end

  it "rejects search text containing null bytes" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:gift, relationship_profile: profile, name: "Hiking guide")

    expect(resolve(user:, memory_query: "hiking\0", source: "gifts")).to be_empty
  end

  it "searches displayed custom relationship types without matching their internal STI name" do
    user = create(:user)
    custom_profile = create(
      :relationship_profile,
      user:,
      type: "RelationshipProfiles::Other",
      profile_attributes: { custom_type_label: "Dentist" }
    )

    visible_results = resolve(user:, memory_query: "dentist", source: "profiles")
    internal_results = resolve(user:, memory_query: "other", source: "profiles")

    expect(visible_results.map { |result| result.source_record.id }).to contain_exactly(custom_profile.id)
    expect(internal_results.map { |result| result.source_record.id }).not_to include(custom_profile.id)
  end

  it "supports explicit archived, relationship, and source filters without accepting foreign relationship ids" do
    user = create(:user)
    archived = create(:relationship_profile, user:, first_name: "Archived", discarded_at: Time.current)
    foreign = create(:relationship_profile, first_name: "Foreign", discarded_at: Time.current)
    archived_gift = create(:gift, relationship_profile: archived, name: "Trail map")
    create(:commitment, relationship_profile: archived, title: "Bring trail map")
    create(:gift, relationship_profile: foreign, name: "Trail map")

    query = described_class.new(
      RelationshipProfile.where(user:),
      params: ActionController::Parameters.new(
        memory_query: "trail map",
        status: "archived",
        relationship_id: archived.id.upcase,
        source: "gifts"
      )
    )

    expect(query.resolve.map(&:source_record)).to contain_exactly(archived_gift)
    expect(query.status).to eq("archived")
    expect(query.relationship_id).to eq(archived.id)
    expect(query.source).to eq("gifts")

    foreign_query = described_class.new(
      RelationshipProfile.where(user:),
      params: ActionController::Parameters.new(source: "gifts", relationship_id: foreign.id)
    )

    expect(foreign_query.resolve).to be_empty
  end

  it "filters recurring important dates by their next occurrence" do
    Timecop.freeze(Time.zone.local(2026, 8, 10, 9, 0, 0)) do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Ana")
      next_month = create(
        :important_date,
        relationship_profile: profile,
        title: "Ana's birthday",
        starts_on: Date.new(1990, 9, 12),
        recurrence: "yearly"
      )
      create(
        :important_date,
        relationship_profile: profile,
        title: "Winter anniversary",
        starts_on: Date.new(2010, 12, 1),
        recurrence: "yearly"
      )

      query = described_class.new(
        RelationshipProfile.where(user:),
        params: ActionController::Parameters.new(source: "important_dates", date_range: "next_month")
      )

      expect(query.resolve.map(&:source_record)).to contain_exactly(next_month)
      expect(query.date_range).to eq("next_month")
    end
  end

  it "anchors monthly and weekly important-date occurrences to the selected range" do
    Timecop.freeze(Time.zone.local(2026, 8, 10, 9, 0, 0)) do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      monthly = create(
        :important_date,
        relationship_profile: profile,
        title: "Monthly dinner",
        starts_on: Date.new(2026, 1, 15),
        recurrence: "monthly"
      )
      weekly = create(
        :important_date,
        relationship_profile: profile,
        title: "Weekly call",
        starts_on: Date.new(2026, 1, 5),
        recurrence: "weekly"
      )

      results = resolve(user:, source: "important_dates", date_range: "next_month")

      expect(results.map(&:source_record)).to contain_exactly(monthly, weekly)
      expect(results.map { |result| result.occurred_on.to_date }).to all(be_in(Date.new(2026, 9, 1)..Date.new(2026, 9, 30)))
    end
  end

  it "evaluates profile birthdays and recurring important dates across the past-year range" do
    Timecop.freeze(Time.zone.local(2026, 8, 10, 9, 0, 0)) do
      user = create(:user)
      profile = create(:relationship_profile, user:, birthday: Date.new(1990, 9, 12))
      yearly = create(
        :important_date,
        relationship_profile: profile,
        title: "Yearly celebration",
        starts_on: Date.new(1990, 9, 12),
        recurrence: "yearly"
      )
      monthly = create(
        :important_date,
        relationship_profile: profile,
        title: "Monthly dinner",
        starts_on: Date.new(2025, 1, 15),
        recurrence: "monthly"
      )
      weekly = create(
        :important_date,
        relationship_profile: profile,
        title: "Weekly call",
        starts_on: Date.new(2025, 1, 6),
        recurrence: "weekly"
      )

      profile_results = resolve(user:, source: "profiles", date_range: "past_year")
      date_results = resolve(user:, source: "important_dates", date_range: "past_year")

      expect(profile_results.map { |result| result.source_record.id }).to contain_exactly(profile.id)
      expect(date_results.map { |result| result.source_record.id }).to contain_exactly(yearly.id, monthly.id, weekly.id)
      expect([ *profile_results, *date_results ].map { |result| result.occurred_on.to_date })
        .to all(be_in(Date.new(2025, 8, 10)..Date.new(2026, 8, 10)))
    end
  end

  it "date-filters computed profile and recurring-date occurrences before their caps" do
    stub_const("#{described_class}::MAX_RESULTS_PER_SOURCE", 1)

    Timecop.freeze(Time.zone.local(2026, 8, 10, 9, 0, 0)) do
      user = create(:user)
      create(:relationship_profile, user:, birthday: Date.new(1990, 1, 10))
      birthday_profile = create(:relationship_profile, user:, birthday: Date.new(1990, 9, 12))
      create(:important_date, relationship_profile: birthday_profile, starts_on: Date.new(2026, 1, 10), recurrence: "none")
      recurring_date = create(
        :important_date,
        relationship_profile: birthday_profile,
        starts_on: Date.new(1990, 9, 15),
        recurrence: "yearly"
      )

      profile_results = resolve(user:, source: "profiles", date_range: "next_month")
      date_results = resolve(user:, source: "important_dates", date_range: "next_month")

      expect(profile_results.map { |result| result.source_record.id }).to contain_exactly(birthday_profile.id)
      expect(date_results.map { |result| result.source_record.id }).to contain_exactly(recurring_date.id)
    end
  end

  it "caps candidates before applying Ruby date normalization" do
    stub_const("#{described_class}::MAX_RESULTS_PER_SOURCE", 1)

    Timecop.freeze(Time.zone.local(2026, 8, 10, 9, 0, 0)) do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:commitment, relationship_profile: profile, title: "Older promise", due_on: Date.new(2026, 7, 1))
      upcoming = create(:commitment, relationship_profile: profile, title: "Upcoming promise", due_on: Date.new(2026, 8, 20))
      commitment_queries = []

      subscriber = lambda do |event|
        commitment_queries << event.payload[:sql] if event.payload[:sql].include?('FROM "commitments"')
      end

      results = ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        resolve(user:, source: "commitments", date_range: "next_30_days")
      end

      expect(results.map(&:source_record)).to contain_exactly(upcoming)
      expect(commitment_queries.one?).to be(true)
      expect(commitment_queries.first).to match(/LIMIT/)
    end
  end

  it "fails malformed scalar filters closed and requires a meaningful search input" do
    user = create(:user)
    create(:relationship_profile, user:, first_name: "Ana")

    query = described_class.new(
      RelationshipProfile.where(user:),
      params: ActionController::Parameters.new(memory_query: { nested: "Ana" }, source: [ "profiles" ], status: "unknown")
    )

    expect(query.resolve).to be_empty
    expect(query).to be_searching
    expect(query.q).to be_nil
    expect(query.source).to eq("all")
    expect(query.status).to eq("active")
  end

  it "does not widen a text search when any submitted filter is invalid" do
    user = create(:user)
    create(:relationship_profile, user:, first_name: "Ana")

    %i[source status date_range relationship_id].each do |filter|
      query = described_class.new(
        RelationshipProfile.where(user:),
        params: ActionController::Parameters.new(memory_query: "Ana", filter => "invalid")
      )

      expect(query.resolve).to be_empty
      expect(query).to be_searching
    end
  end

  it "deduplicates derivative timeline records in favor of their direct source" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    commitment = create(:commitment, relationship_profile: profile, title: "Book alpine cabin")
    create(
      :timeline_entry,
      relationship_profile: profile,
      source_record: commitment,
      origin: "system",
      entry_type: "promise",
      title: commitment.title
    )

    results = resolve(user:, memory_query: "alpine")

    expect(results.map(&:source_record)).to contain_exactly(commitment)
    expect(results.map(&:source_type)).to contain_exactly("commitments")
  end

  it "bounds candidates loaded from each source before Ruby normalization" do
    stub_const("#{described_class}::MAX_RESULTS_PER_SOURCE", 2)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create_list(:gift, 3, relationship_profile: profile, name: "Trail guide")

    results = resolve(user:, memory_query: "trail", source: "gifts")

    expect(results.size).to eq(2)
  end

  it "orders source candidates deterministically before applying the cap" do
    stub_const("#{described_class}::MAX_RESULTS_PER_SOURCE", 1)

    Timecop.freeze(Time.zone.local(2026, 8, 10, 9, 0, 0)) do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:gift, relationship_profile: profile, name: "Trail guide", status: "given", given_on: 1.month.ago.to_date)
      recent = create(:gift, relationship_profile: profile, name: "Trail guide", status: "given", given_on: Date.current)

      results = resolve(user:, memory_query: "trail", source: "gifts")

      expect(results.map(&:source_record)).to contain_exactly(recent)
    end
  end

  it "orders and caps timeline entries and interactions as one source" do
    stub_const("#{described_class}::MAX_RESULTS_PER_SOURCE", 1)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:timeline_entry, relationship_profile: profile, title: "Alpine notes", occurred_at: 2.days.ago)
    recent_interaction = create(:interaction, relationship_profile: profile, notes: "Alpine follow-up", occurred_at: 1.day.ago)

    results = resolve(user:, memory_query: "alpine", source: "timeline")

    expect(results.map(&:source_record)).to contain_exactly(recent_interaction)
  end

  it "does not apply the per-source result cap to the owner profile subquery" do
    stub_const("#{described_class}::MAX_RESULTS_PER_SOURCE", 2)
    user = create(:user)
    profiles = 3.times.map do |index|
      create(:relationship_profile, user:, created_at: index.days.from_now)
    end
    note = create(:relationship_note, relationship_profile: profiles.last, body: "Alpine trail plans")
    relation = RelationshipProfile.where(user:).order(:created_at)

    results = described_class.new(
      relation,
      params: ActionController::Parameters.new(memory_query: "alpine", source: "notes")
    ).resolve

    expect(results.map(&:source_record)).to contain_exactly(note)
  end

  it "searches text displayed by interactions derived from mood notes" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    mood_note = create(:mood_note, relationship_profile: profile, observation: "Quiet after the alpine trip")
    interaction = create(:interaction, :derived_from_mood_note, source: mood_note, relationship_profile: profile)

    results = resolve(user:, memory_query: "alpine", source: "timeline")

    expect(results.map(&:source_record)).to contain_exactly(interaction)
    expect(results.first.excerpt).to eq(mood_note.observation)
  end

  it "localizes standard relationship note categories" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(:relationship_note, relationship_profile: profile, category: "General", body: "Alpine plans")

    results = I18n.with_locale(:es) { resolve(user:, memory_query: "alpine", source: "notes") }

    expect(results.map(&:source_record)).to contain_exactly(note)
    expect(results.first.title).to eq("Nota")
  end

  it "matches localized preference enum labels" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    preference = create(
      :relationship_preference,
      relationship_profile: profile,
      key: "Reuniones",
      value: "Grupos pequeños",
      category: "social_settings",
      confidence: "confirmed"
    )

    category_results = I18n.with_locale(:es) do
      resolve(user:, memory_query: "Entornos sociales", source: "preferences")
    end
    confidence_results = I18n.with_locale(:es) do
      resolve(user:, memory_query: "Confirmada", source: "preferences")
    end

    expect(category_results.map(&:source_record)).to contain_exactly(preference)
    expect(confidence_results.map(&:source_record)).to contain_exactly(preference)
  end

  it "matches localized labels displayed by structured result sources" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(:relationship_note, relationship_profile: profile, category: "General", body: "Planning details")
    timeline_entry = create(:timeline_entry, relationship_profile: profile, entry_type: "apology", title: "Made amends", body: nil)
    interaction = create(:interaction, relationship_profile: profile, interaction_type: "video", notes: nil)
    commitment = create(:commitment, relationship_profile: profile, status: "completed", title: "Followed up", notes: nil)
    gift = create(:gift, relationship_profile: profile, status: "given", outcome: "successful", name: "Guidebook", notes: nil)
    important_date = create(
      :important_date,
      relationship_profile: profile,
      date_type: "birthday",
      importance_level: "essential",
      title: nil,
      notes: nil
    )

    expectations = {
      [ "Nota", "notes" ] => note,
      [ "Disculpa", "timeline" ] => timeline_entry,
      [ "Videollamada", "timeline" ] => interaction,
      [ "Completado", "commitments" ] => commitment,
      [ "Entregado", "gifts" ] => gift,
      [ "Cumpleaños", "important_dates" ] => important_date,
      [ "Esencial", "important_dates" ] => important_date
    }

    I18n.with_locale(:es) do
      expectations.each do |(memory_query, source), expected_record|
        results = resolve(user:, memory_query:, source:)

        expect(results.map(&:source_record)).to include(expected_record)
      end
    end
  end

  it "emits privacy-minimized search instrumentation" do
    user = create(:user)
    profile = create(:relationship_profile, user:, first_name: "Ana")
    create(:gift, relationship_profile: profile, name: "Hiking daypack")
    payloads = []

    subscriber = ActiveSupport::Notifications.subscribe("relationship_memory_search.query") do |event|
      payloads << event.payload
    end

    resolve(user:, memory_query: "hiking", source: "gifts")

    expect(payloads).to contain_exactly(
      source: "gifts",
      status: "active",
      date_range: "all",
      relationship_filter: false,
      result_count: 1
    )
    expect(payloads.first).not_to have_key(:q)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  it "filters private query text from Active Record SQL logs" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:gift, relationship_profile: profile, name: "private-alpine-plan")
    log_output = StringIO.new
    logger = ActiveSupport::Logger.new(log_output)
    logger.level = Logger::DEBUG
    previous_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = logger

    resolve(user:, memory_query: "private-alpine-plan", source: "gifts")

    expect(log_output.string).not_to include("private-alpine-plan")
    expect(log_output.string).to include("[FILTERED]")
  ensure
    ActiveRecord::Base.logger = previous_logger
  end

  def resolve(user:, **params)
    described_class.new(
      RelationshipProfile.where(user:),
      params: ActionController::Parameters.new(params)
    ).resolve
  end
end
