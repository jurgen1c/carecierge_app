require "rails_helper"

RSpec.describe PurgeAbandonedSocialContextUploadJob, type: :job do
  it "purges an expired owner-stamped upload that was never attached" do
    user = create(:user)
    now = Time.zone.local(2026, 8, 14, 9, 0)
    blob = nil

    Timecop.freeze(now) do
      blob = create_social_context_image_blob(user:, filename: "abandoned.png")
    end
    blob_key = blob.key

    Timecop.freeze(now + described_class::RETENTION_PERIOD) do
      described_class.perform_now(blob.id, user.id)
    end

    expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
    expect(ActiveStorage::Blob.service.exist?(blob_key)).to be(false)
  end

  it "preserves an upload that has become attached" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    now = Time.zone.local(2026, 8, 14, 9, 0)
    blob = nil

    Timecop.freeze(now) do
      blob = create_social_context_image_blob(user:, filename: "saved.png")
      create(
        :social_context_note,
        relationship_profile: profile,
        body: "<p>Saved context</p>#{ActionText::Attachment.from_attachable(blob).to_html}"
      )
    end

    Timecop.freeze(now + described_class::RETENTION_PERIOD) do
      described_class.perform_now(blob.id, user.id)
    end

    expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
    expect(ActiveStorage::Blob.service.exist?(blob.key)).to be(true)
  ensure
    blob&.purge if blob&.persisted?
  end

  it "preserves an upload until its retention period has elapsed" do
    user = create(:user)
    now = Time.zone.local(2026, 8, 14, 9, 0)
    blob = nil

    Timecop.freeze(now) do
      blob = create_social_context_image_blob(user:, filename: "recent.png")
    end

    Timecop.freeze(now + described_class::RETENTION_PERIOD - 1.second) do
      described_class.perform_now(blob.id, user.id)
    end

    expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
  ensure
    blob&.purge if blob&.persisted?
  end
end
