module SocialContextNotes
  AnalysisInput = Data.define(:text, :image_blob_ids) do
    def initialize(text:, image_blob_ids:)
      super(
        text: text.to_s.squish.first(SocialContextNote::MAX_BODY_CHARACTERS).freeze,
        image_blob_ids: Array(image_blob_ids).first(SocialContextNote::MAX_IMAGES).map(&:to_s).freeze
      )
    end
  end
end
