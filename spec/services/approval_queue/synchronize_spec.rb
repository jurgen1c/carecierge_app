require "rails_helper"

RSpec.describe ApprovalQueue::Synchronize do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }

  it "uses a no-key account lock so child decision evidence cannot deadlock" do
    expect(user).to receive(:with_lock).with("FOR NO KEY UPDATE").and_call_original

    described_class.call(user:)
  end

  it "locks every candidate profile in UUID order before processing work" do
    profiles = 2.times.map { create(:relationship_profile, user:) }
    memories = profiles.map do |relationship_profile|
      create(:memory_record, relationship_profile:, source: "ai_inferred", confidence: "low")
    end
    expected_profile_ids = profiles.map(&:id).sort
    lock_sequence = []

    allow_any_instance_of(RelationshipProfile).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      lock_sequence << method.receiver.id
      method.call(*args, &block)
    end

    described_class.new(user:).send(:with_ordered_profile_locks, memories.reverse) do
      lock_sequence << :work
    end

    expect(lock_sequence).to eq([ *expected_profile_ids, :work ])
  end

  it "preloads candidate profiles in one query before constructing the lock order" do
    profiles = 2.times.map { create(:relationship_profile, user:) }
    subjects = profiles.flat_map do |relationship_profile|
      2.times.map do
        create(:memory_record, relationship_profile:, source: "ai_inferred", confidence: "low")
      end
    end.map { |subject| MemoryRecord.find(subject.id) }
    synchronizer = described_class.new(user:)

    queries = capture_sql do
      @ordered_profiles = synchronizer.send(:preload_ordered_profiles, subjects)
    end

    expect(@ordered_profiles.map(&:id)).to eq(profiles.map(&:id).sort)
    expect(subjects).to all(satisfy { |subject| subject.association(:relationship_profile).loaded? })
    expect(queries.grep(/SELECT .* FROM "relationship_profiles"/).size).to eq(1)
  end

  it "reuses the batch profile lock while processing each source" do
    3.times do
      create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    end

    queries = capture_sql { described_class.call(user:) }
    profile_lock_queries = queries.grep(/SELECT .* FROM "relationship_profiles".*FOR UPDATE/)

    expect(profile_lock_queries.size).to eq(1)
  end

  it "does not reload a preloaded profile after locking each source" do
    3.times do
      create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    end

    queries = capture_sql { described_class.call(user:) }
    per_source_profile_queries = queries.grep(
      /SELECT .* FROM "relationship_profiles" WHERE "relationship_profiles"\."id" = .* LIMIT/
    ).reject { |query| query.include?("FOR UPDATE") }

    expect(per_source_profile_queries).to be_empty
  end

  it "loads privacy-vault state once for the locked memory batch" do
    3.times do
      create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    end

    queries = capture_sql { described_class.call(user:) }
    vault_queries = queries.grep(/SELECT .* FROM "privacy_vault_items"/)

    expect(vault_queries.size).to eq(1)
  end

  it "queues pending extracted memories and blocked high-impact memories once" do
    recap = create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review")
    proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: recap, confidence: "low")
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "inferred")
    create(:memory_record, relationship_profile: profile, source: "user_confirmed", confidence: "confirmed")

    expect { described_class.call(user:) }.to change(ApprovalRequest, :count).by(2)
    expect { described_class.call(user:) }.not_to change(ApprovalRequest, :count)

    expect(user.approval_requests.find_by(subject: proposal)).to have_attributes(
      kind: "extracted_memory",
      action_key: "review_extracted_memory",
      risk_level: "medium",
      confidence: "low"
    )
    expect(user.approval_requests.find_by(subject: memory)).to have_attributes(
      kind: "memory_record",
      action_key: "approve_high_impact_memory",
      risk_level: "high",
      confidence: "inferred"
    )
  end

  it "bounds source reconciliation work for each queue visit" do
    stub_const("ApprovalQueue::Synchronize::SOURCE_LIMIT", 2)
    3.times do
      create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    end

    expect { described_class.call(user:) }.to change(ApprovalRequest, :count).by(2)
  end

  it "bounds reconciliation of existing open requests for each queue visit" do
    stub_const("ApprovalQueue::Synchronize::REQUEST_LIMIT", 2)
    memories = 3.times.map do
      create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    end
    described_class.call(user:)
    memories.each { |memory| memory.update!(source: "user_confirmed", confidence: "confirmed") }

    described_class.call(user:)

    expect(user.approval_requests.where(status: "superseded").count).to eq(2)
    expect(user.approval_requests.open.count).to eq(1)
  end

  it "does not let unchanged eligible requests starve later ineligible work" do
    stub_const("ApprovalQueue::Synchronize::REQUEST_LIMIT", 2)
    2.times do
      memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
      create(
        :approval_request,
        user:,
        subject: memory,
        kind: "memory_record",
        action_key: "approve_high_impact_memory",
        risk_level: "high",
        confidence: "low"
      )
    end
    stale_memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    stale_request = create(
      :approval_request,
      user:,
      subject: stale_memory,
      kind: "memory_record",
      action_key: "approve_high_impact_memory",
      risk_level: "high",
      confidence: "low"
    )
    stale_memory.update!(source: "user_confirmed", confidence: "confirmed")

    2.times { described_class.call(user:) }

    expect(stale_request.reload.status).to eq("superseded")
  end

  it "never imports another owner's pending work" do
    foreign_profile = create(:relationship_profile)
    proposal = create(:extracted_memory, relationship_profile: foreign_profile, conversation_recap: create(:conversation_recap, relationship_profile: foreign_profile))

    described_class.call(user:)

    expect(ApprovalRequest.find_by(subject: proposal)).to be_nil
  end

  it "removes an open request whose source disappeared before reconciliation" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    approval_request = create(
      :approval_request,
      user:,
      subject: memory,
      kind: "memory_record",
      action_key: "approve_high_impact_memory",
      risk_level: "high",
      confidence: "low"
    )
    memory.delete

    expect { described_class.call(user:) }.to change(ApprovalRequest, :count).by(-1)
    expect(ApprovalRequest.exists?(approval_request.id)).to be(false)
  end

  it "does not queue protected high-impact memory" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    PrivacyVault::Protect.call(actor: user, protectable: memory)

    described_class.call(user:)

    expect(user.approval_requests.find_by(subject: memory)).to be_nil
  end

  it "refreshes an open request after an eligible source edit and invalidates its old lock" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    described_class.call(user:)
    approval_request = user.approval_requests.find_by!(subject: memory)
    original_lock_version = approval_request.lock_version

    memory.update!(body: "Updated source-backed detail", confidence: "inferred")
    described_class.call(user:)

    expect(approval_request.reload).to have_attributes(
      status: "pending",
      confidence: "inferred",
      subject_updated_at: memory.updated_at
    )
    expect(approval_request.lock_version).to be > original_lock_version
  end

  it "supersedes an open request when the source is no longer eligible" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    described_class.call(user:)
    approval_request = user.approval_requests.find_by!(subject: memory)

    memory.update!(source: "user_confirmed", confidence: "confirmed")
    described_class.call(user:)

    expect(approval_request.reload).to have_attributes(status: "superseded", decided_at: be_present)
    expect(user.approval_requests.open.find_by(subject: memory)).to be_nil
  end

  it "supersedes open work when its relationship is archived" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    described_class.call(user:)
    approval_request = user.approval_requests.find_by!(subject: memory)

    profile.archive!
    described_class.call(user:)

    expect(approval_request.reload.status).to eq("superseded")
    expect(user.approval_requests.open.find_by(subject: memory)).to be_nil
  end

  it "requeues superseded work when temporary ineligibility ends without a source edit" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    described_class.call(user:)
    approval_request = user.approval_requests.find_by!(subject: memory)
    source_updated_at = memory.updated_at

    profile.archive!
    described_class.call(user:)
    profile.undiscard!

    expect { described_class.call(user:) }.to change(ApprovalRequest, :count).by(1)
    expect(approval_request.reload.status).to eq("superseded")
    expect(memory.reload.updated_at).to eq(source_updated_at)
    expect(user.approval_requests.open.find_by!(subject: memory)).to have_attributes(
      status: "pending",
      subject_updated_at: source_updated_at
    )
  end

  it "revalidates a stale source instance immediately before enqueueing" do
    recap = create(:conversation_recap, relationship_profile: profile)
    proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: recap)
    stale_proposal = ExtractedMemory.find(proposal.id)
    proposal.update_columns(status: "approved", reviewed_at: Time.current, updated_at: Time.current)
    synchronizer = described_class.new(user:)

    synchronizer.send(
      :enqueue,
      subject: stale_proposal,
      action_key: "review_extracted_memory"
    )

    expect(user.approval_requests.find_by(subject: proposal)).to be_nil
  end

  it "derives request metadata from the source after locking and reloading it" do
    recap = create(:conversation_recap, relationship_profile: profile)
    proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: recap, confidence: "high")
    stale_proposal = ExtractedMemory.find(proposal.id)
    proposal.update_columns(confidence: "low", updated_at: Time.current)
    synchronizer = described_class.new(user:)

    synchronizer.send(
      :enqueue,
      subject: stale_proposal,
      action_key: "review_extracted_memory"
    )

    expect(user.approval_requests.find_by!(subject: proposal)).to have_attributes(
      kind: "extracted_memory",
      risk_level: "medium",
      confidence: "low",
      subject_updated_at: proposal.reload.updated_at
    )
  end

  it "does not recreate a terminal request until the source meaningfully changes" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    described_class.call(user:)
    approval_request = user.approval_requests.find_by!(subject: memory)
    ApprovalDecisions::Apply.call(
      approval_request:,
      actor: user,
      decision: "reject",
      lock_version: approval_request.lock_version
    )

    expect { described_class.call(user:) }.not_to change(ApprovalRequest, :count)

    memory.update!(body: "Updated source-backed detail")

    expect { described_class.call(user:) }.to change(ApprovalRequest, :count).by(1)
    expect(user.approval_requests.open.find_by(subject: memory)).to be_present
  end

  it "keeps dismissed pending proposals out of the queue" do
    recap = create(:conversation_recap, relationship_profile: profile)
    proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: recap)
    described_class.call(user:)
    approval_request = user.approval_requests.find_by!(subject: proposal)
    ApprovalDecisions::Apply.call(
      approval_request:,
      actor: user,
      decision: "dismiss",
      lock_version: approval_request.lock_version
    )

    expect { described_class.call(user:) }.not_to change(ApprovalRequest, :count)
    expect(user.approval_requests.open.find_by(subject: proposal)).to be_nil
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
