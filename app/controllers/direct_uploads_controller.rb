class DirectUploadsController < ApplicationController
  include ActiveStorage::SetCurrent

  skip_forgery_protection only: :update

  def create
    return head :unprocessable_content unless acceptable_blob_args?

    current_user.with_lock do
      blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_args)
      blob.update!(uploaded_by_user_id: current_user.id)
      PurgeAbandonedSocialContextUploadJob
        .set(wait: PurgeAbandonedSocialContextUploadJob::RETENTION_PERIOD)
        .perform_later(blob.id, current_user.id)
      render json: direct_upload_json(blob)
    end
  rescue ActionController::ParameterMissing
    head :unprocessable_content
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def update
    blob = upload_blob
    return head :not_found unless owned_by_current_user?(blob)

    current_user.with_lock do
      blob.with_lock do
        return head :not_found unless owned_by_current_user?(blob)
        return head :unprocessable_content unless acceptable_upload?(blob)

        blob.upload_without_unfurling(request.body)
      end
    end

    head :no_content
  rescue ActiveRecord::RecordNotFound, ActiveSupport::MessageVerifier::InvalidSignature
    head :not_found
  rescue ActiveStorage::IntegrityError
    head :unprocessable_content
  end

  private

  def blob_args
    @blob_args ||= params.expect(blob: [ :filename, :byte_size, :checksum, :content_type, metadata: {} ])
      .to_h
      .symbolize_keys
      .tap do |attributes|
        attributes[:metadata] = attributes[:metadata].to_h.except("uploaded_by_user_id")
      end
  end

  def acceptable_blob_args?
    SocialContextNote::IMAGE_CONTENT_TYPES.include?(blob_args[:content_type].to_s) &&
      blob_args[:byte_size].to_i.between?(1, SocialContextNote::MAX_IMAGE_BYTES)
  end

  def direct_upload_json(blob)
    blob.as_json(root: false, methods: :signed_id).merge(
      direct_upload: {
        url: social_context_direct_upload_url(
          signed_id: blob.signed_id(
            expires_in: PurgeAbandonedSocialContextUploadJob::GRANT_TTL,
            purpose: :authenticated_direct_upload
          )
        ),
        headers: blob.service_headers_for_direct_upload
      }
    )
  end

  def upload_blob
    ActiveStorage::Blob.find_signed!(params[:signed_id], purpose: :authenticated_direct_upload)
  end

  def owned_by_current_user?(blob)
    blob.uploaded_by_user_id.to_s == current_user.id.to_s
  end

  def acceptable_upload?(blob)
    request.content_length == blob.byte_size && request.content_mime_type.to_s == blob.content_type
  end
end
