require "rails_helper"

# == Schema Information
#
# Table name: backup_plans
# Database name: primary
#
#  id                            :uuid             not null, primary key
#  event_plan_generation_version :bigint           not null
#  generated_at                  :datetime         not null
#  include_private_notes         :boolean          default(FALSE), not null
#  include_vault_context         :boolean          default(FALSE), not null
#  locale                        :string           default("en"), not null
#  lock_version                  :integer          default(0), not null
#  promoted_at                   :datetime
#  scenario                      :string           not null
#  source_context                :text             not null
#  status                        :string           default("generated"), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  event_plan_id                 :uuid             not null
#  user_id                       :uuid             not null
#
# Indexes
#
#  index_backup_plans_on_event_plan_id          (event_plan_id)
#  index_backup_plans_on_plan_status_generated  (event_plan_id,status,generated_at)
#  index_backup_plans_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
RSpec.describe BackupPlan, type: :model do
  subject(:backup_plan) { build(:backup_plan) }

  it "owns options and belongs to a user and event plan" do
    expect(described_class.reflect_on_association(:user).macro).to eq(:belongs_to)
    expect(described_class.reflect_on_association(:event_plan).macro).to eq(:belongs_to)
    options = described_class.reflect_on_association(:backup_options)
    expect(options.macro).to eq(:has_many)
    expect(options.options[:dependent]).to eq(:destroy)
  end

  it "requires the plan and user to share an owner" do
    backup_plan.user = create(:user)

    expect(backup_plan).not_to be_valid
    expect(backup_plan.errors[:event_plan]).to include("must belong to you")
  end

  it "accepts only supported scenarios, statuses, and locales" do
    backup_plan.scenario = "surprise_dragon"
    backup_plan.status = "waiting"
    backup_plan.locale = "fr"

    expect(backup_plan).not_to be_valid
    expect(backup_plan.errors).to include(:scenario, :status, :locale)
  end

  it "requires bounded source provenance" do
    backup_plan.source_context = []

    expect(backup_plan).not_to be_valid
    expect(backup_plan.errors[:source_context]).to be_present
  end

  it "requires a SHA-256 context fingerprint" do
    backup_plan.context_fingerprint = "not-a-fingerprint"

    expect(backup_plan).not_to be_valid
    expect(backup_plan.errors[:context_fingerprint]).to be_present
  end

  it "encrypts selected source context at rest" do
    backup_plan = create(:backup_plan, source_context: [
      {
        "id" => "private_note:secret",
        "label" => "Private dinner constraint",
        "certainty" => "confirmed",
        "sensitive" => true
      }
    ])

    raw = ApplicationRecord.connection.select_value(
      ApplicationRecord.sanitize_sql_array([
        "SELECT source_context FROM backup_plans WHERE id = ?",
        backup_plan.id
      ])
    )

    expect(raw).not_to include("Private dinner constraint")
    expect(backup_plan.reload.source_context.sole.fetch("sensitive")).to be(true)
  end
end
