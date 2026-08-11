module RelationshipMemorySearch
  class SearchResult
    attr_reader :relationship_profile, :source_record, :source_type, :title, :excerpt, :occurred_on

    def initialize(relationship_profile:, source_record:, source_type:, title:, excerpt:, occurred_on: nil)
      @relationship_profile = relationship_profile
      @source_record = source_record
      @source_type = source_type
      @title = title.to_s.squish
      @excerpt = excerpt.to_s.squish
      @occurred_on = occurred_on&.to_date
    end
  end
end
