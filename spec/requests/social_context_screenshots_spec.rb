require "rails_helper"

RSpec.describe "Social context screenshots", type: :request do
  it "serves a bounded owner-stamped preview only to the authenticated owner" do
    owner = create(:user)
    original = Vips::Image.black(1600, 1200).pngsave_buffer
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(original),
      filename: "private-context.png",
      content_type: "image/png"
    ).tap { |record| record.update!(uploaded_by_user_id: owner.id) }
    path = social_context_screenshot_path(signed_id: blob.signed_id, filename: blob.filename)

    get path
    expect(response).to have_http_status(:unauthorized)

    sign_in create(:user)
    get path
    expect(response).to have_http_status(:forbidden)

    sign_in owner
    get path

    expect(response).to have_http_status(:success)
    expect(response.media_type).to eq("image/png")
    preview = Vips::Image.new_from_buffer(response.body.b, "")
    expect(preview.width).to be <= 1024
    expect(preview.height).to be <= 768
    expect(response.headers["Cache-Control"]).to include("no-store")
  ensure
    blob&.purge if blob&.persisted?
  end
end
