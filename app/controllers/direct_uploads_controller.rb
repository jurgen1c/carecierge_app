class DirectUploadsController < ApplicationController
  include ActiveStorage::SetCurrent

  def create
    blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_args)
    render json: direct_upload_json(blob)
  end

  private

  def blob_args
    attributes = params.expect(blob: [ :filename, :byte_size, :checksum, :content_type, metadata: {} ])
      .to_h
      .symbolize_keys
    attributes[:metadata] = attributes[:metadata].to_h.merge("uploaded_by_user_id" => current_user.id)
    attributes
  end

  def direct_upload_json(blob)
    blob.as_json(root: false, methods: :signed_id).merge(
      direct_upload: {
        url: blob.service_url_for_direct_upload,
        headers: blob.service_headers_for_direct_upload
      }
    )
  end
end
