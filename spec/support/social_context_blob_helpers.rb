module SocialContextBlobHelpers
  PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze

  def social_context_png_bytes(payload = "")
    PNG_SIGNATURE + payload.b
  end

  def create_social_context_image_blob(user:, filename:, payload: "")
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(social_context_png_bytes(payload)),
      filename:,
      content_type: "image/png"
    ).tap { |blob| blob.update!(uploaded_by_user_id: user.id) }
  end
end

RSpec.configure do |config|
  config.include SocialContextBlobHelpers
end
