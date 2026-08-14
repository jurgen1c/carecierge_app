module DataDeletions
  class DeleteBlobs
    def self.call(blobs)
      Array(blobs).uniq(&:id).each { |blob| delete_blob(blob) }
    end

    def self.delete_blob(blob)
      blob.with_lock do
        return if blob.attachments.exists?

        blob.delete
        blob.destroy!
      end
    rescue ActiveRecord::RecordNotFound
      blob.delete
    end
    private_class_method :delete_blob
  end
end
