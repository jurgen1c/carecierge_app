require "rails_helper"

RSpec.describe "Authenticated direct uploads", type: :request do
  let(:blob_params) do
    {
      filename: "social-context.png",
      byte_size: 8,
      checksum: Digest::MD5.base64digest("\x89PNG\r\n\x1A\n".b),
      content_type: "image/png",
      metadata: { uploaded_by_user_id: "spoofed-account" }
    }
  end

  it "requires an authenticated account" do
    expect do
      post social_context_direct_uploads_path, params: { blob: blob_params }
    end.not_to change(ActiveStorage::Blob, :count)

    expect(response).to redirect_to(new_user_session_path)
  end

  it "records the authenticated owner only in the foreign-key-backed column" do
    user = create(:user)
    sign_in user

    expect do
      post social_context_direct_uploads_path, params: { blob: blob_params }
    end.to change(ActiveStorage::Blob, :count).by(1)

    expect(response).to have_http_status(:success)
    blob = ActiveStorage::Blob.order(:created_at).last
    expect(blob).to have_attributes(uploaded_by_user_id: user.id)
    expect(blob.metadata).not_to have_key("uploaded_by_user_id")
  end

  it "schedules age-bounded cleanup for an abandoned upload" do
    user = create(:user)
    sign_in user
    now = Time.zone.local(2026, 8, 14, 9, 0)

    Timecop.freeze(now) do
      post social_context_direct_uploads_path, params: { blob: blob_params }

      blob = ActiveStorage::Blob.order(:created_at).last
      expect(PurgeAbandonedSocialContextUploadJob).to have_been_enqueued
        .with(blob.id, user.id)
        .at(now + PurgeAbandonedSocialContextUploadJob::RETENTION_PERIOD)
    end
  end

  it "stores bytes through an authenticated, owner-scoped upload grant" do
    user = create(:user)
    sign_in user

    post social_context_direct_uploads_path, params: { blob: blob_params }

    blob = ActiveStorage::Blob.order(:created_at).last
    upload_url = response.parsed_body.dig("direct_upload", "url")

    put upload_url, params: "\x89PNG\r\n\x1A\n".b, headers: { "CONTENT_TYPE" => "image/png" }

    expect(response).to have_http_status(:no_content)
    expect(blob.service.download(blob.key)).to eq("\x89PNG\r\n\x1A\n".b)
  ensure
    blob&.purge if blob&.persisted?
  end

  it "does not let another account use an upload grant" do
    owner = create(:user)
    sign_in owner
    post social_context_direct_uploads_path, params: { blob: blob_params }
    blob = ActiveStorage::Blob.order(:created_at).last
    upload_url = response.parsed_body.dig("direct_upload", "url")

    sign_in create(:user)
    put upload_url, params: "\x89PNG\r\n\x1A\n".b, headers: { "CONTENT_TYPE" => "image/png" }

    expect(response).to have_http_status(:not_found)
    expect(blob.service.exist?(blob.key)).to be(false)
  ensure
    blob&.purge if blob&.persisted?
  end

  it "rejects grants outside the social screenshot type and size bounds" do
    user = create(:user)
    sign_in user

    expect do
      post social_context_direct_uploads_path, params: {
        blob: blob_params.merge(content_type: "text/plain", byte_size: SocialContextNote::MAX_IMAGE_BYTES + 1)
      }
    end.not_to change(ActiveStorage::Blob, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects bytes that do not match the upload grant" do
    user = create(:user)
    sign_in user
    post social_context_direct_uploads_path, params: { blob: blob_params }
    blob = ActiveStorage::Blob.order(:created_at).last
    upload_url = response.parsed_body.dig("direct_upload", "url")

    put upload_url, params: "short", headers: { "CONTENT_TYPE" => "image/png" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(blob.service.exist?(blob.key)).to be(false)
  ensure
    blob&.purge if blob&.persisted?
  end

  it "preserves the existing global Active Storage upload contract" do
    expect do
      post rails_direct_uploads_path, params: {
        blob: blob_params.merge(
          filename: "reference.pdf",
          content_type: "application/pdf",
          byte_size: SocialContextNote::MAX_IMAGE_BYTES + 1
        )
      }
    end.to change(ActiveStorage::Blob, :count).by(1)

    expect(response).to have_http_status(:success)
    expect(ActiveStorage::Blob.order(:created_at).last.uploaded_by_user_id).to be_nil
  end
end
