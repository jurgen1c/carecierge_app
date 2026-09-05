require "rails_helper"

RSpec.describe AdminDashboard::QueueStatus do
  around { |example| Timecop.freeze(Time.zone.local(2026, 9, 5, 12)) { example.run } }

  before do
    %w[FailedExecution ReadyExecution ScheduledExecution BlockedExecution Process].each do |name|
      stub_const("SolidQueue::#{name}", double(name, table_exists?: true))
    end
  end

  it "reports unavailable when queue tables are absent" do
    allow(SolidQueue::FailedExecution).to receive(:table_exists?).and_return(false)
    expect(described_class.new.metrics).to eq(queue_available: false)
  end

  it "reports counts and recent workers without reading payloads" do
    [ SolidQueue::FailedExecution, SolidQueue::ReadyExecution, SolidQueue::ScheduledExecution, SolidQueue::BlockedExecution, SolidQueue::Process ].each do |model|
      allow(model).to receive(:table_exists?).and_return(true)
    end
    allow(SolidQueue::FailedExecution).to receive(:count).and_return(2)
    allow(SolidQueue::ReadyExecution).to receive(:count).and_return(3)
    allow(SolidQueue::ScheduledExecution).to receive(:count).and_return(4)
    allow(SolidQueue::BlockedExecution).to receive(:count).and_return(5)
    workers = instance_double(ActiveRecord::Relation)
    allow(SolidQueue::Process).to receive(:where).with(kind: "Worker", last_heartbeat_at: 5.minutes.ago..).and_return(workers)
    allow(workers).to receive(:count).and_return(1)
    expect(described_class.new.metrics).to eq(queue_available: true, jobs_failed: 2, jobs_ready: 3, jobs_scheduled: 4, jobs_blocked: 5, workers_recent: 1)
  end

  it "contains queue database failures without logging exception payloads" do
    allow(SolidQueue::FailedExecution).to receive(:table_exists?).and_raise(ActiveRecord::ConnectionNotEstablished, "secret connection")
    expect(Rails.logger).to receive(:warn).with("admin_dashboard.queue_unavailable")
    expect(described_class.new.metrics).to eq(queue_available: false)
  end
end
