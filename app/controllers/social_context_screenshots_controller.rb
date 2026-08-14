class SocialContextScreenshotsController < ApplicationController
  PREVIEW_SIZE = [ 1024, 768 ].freeze

  def show
    blob = ActiveStorage::Blob.find_signed!(params[:signed_id])
    authorize blob, :show?, policy_class: SocialContextScreenshotPolicy
    preview = blob.variant(resize_to_limit: PREVIEW_SIZE).processed

    response.headers["Cache-Control"] = "private, no-store"
    send_data preview.download,
      type: preview.content_type,
      disposition: "inline",
      filename: preview.filename.to_s
  rescue ActiveRecord::RecordNotFound,
    ActiveStorage::FileNotFoundError,
    ActiveStorage::InvariableError,
    ActiveStorage::UnrepresentableError,
    ImageProcessing::Error,
    ActiveSupport::MessageVerifier::InvalidSignature
    head :not_found
  end
end
