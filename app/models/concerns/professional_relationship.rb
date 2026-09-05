module ProfessionalRelationship
  extend ActiveSupport::Concern

  class ModeChangedError < StandardError; end

  included do
    serialize :professional_context, coder: JSON
    encrypts :professional_context
    validates :relationship_mode, inclusion: { in: %w[personal professional] }
    before_validation :normalize_work_source_ids
    validate :professional_context_is_valid, if: :will_save_change_to_professional_context?
    before_update :fence_professional_context_changes
  end

  def ensure_generation_mode!(expected_mode)
    raise ModeChangedError unless relationship_mode == expected_mode
  end

  def professional_context
    super || {}
  end

  def professional?
    relationship_mode == "professional"
  end

  def professional_gifts_allowed?
    professional? && professional_context["gifts_allowed"] == "1" && professional_context["boundaries"].present?
  end

  def work_context(as_of: nil)
    ProfessionalContext.new(self, as_of:)
  end

  private

  def normalize_work_source_ids
    return unless professional_context.is_a?(Hash)

    ProfessionalContext::COLLECTIONS.each do |key|
      professional_context[key] = professional_context[key].compact_blank.uniq if professional_context[key].is_a?(Array)
    end
  end

  def professional_context_is_valid
    context = professional_context
    return errors.add(:professional_context, :invalid) unless context.is_a?(Hash)

    valid = (context.keys - ProfessionalContext::FIELDS - ProfessionalContext::COLLECTIONS - [ "gifts_allowed" ]).empty?
    valid &&= ProfessionalContext::FIELDS.all? { |key| context[key].nil? || (context[key].is_a?(String) && context[key].length <= 1000) }
    valid &&= context["gifts_allowed"].nil? || context["gifts_allowed"].in?(%w[0 1])
    valid &&= ProfessionalContext::COLLECTIONS.all? do |key|
      ids = context.fetch(key, [])
      ids.is_a?(Array) && ids.length <= 6 && ids.all? { |id| id.is_a?(String) && id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i) } &&
        (ids.reject(&:blank?) - work_context.candidates(key).where(id: ids.reject(&:blank?)).pluck(:id)).empty?
    end
    errors.add(:professional_context, :invalid) unless valid
  end

  def fence_professional_context_changes
    return unless will_save_change_to_relationship_mode? || will_save_change_to_professional_context?

    self.message_draft_generation_version += 1
    self.briefing_generation_version += 1
    self.gift_recommendation_generation_version += 1
  end
end
