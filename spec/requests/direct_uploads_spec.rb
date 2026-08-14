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
      post rails_direct_uploads_path, params: { blob: blob_params }
    end.not_to change(ActiveStorage::Blob, :count)

    expect(response).to redirect_to(new_user_session_path)
  end

  it "records the authenticated owner instead of trusting client metadata" do
    user = create(:user)
    sign_in user

    expect do
      post rails_direct_uploads_path, params: { blob: blob_params }
    end.to change(ActiveStorage::Blob, :count).by(1)

    expect(response).to have_http_status(:success)
    expect(ActiveStorage::Blob.order(:created_at).last.metadata).to include("uploaded_by_user_id" => user.id)
  end
end
