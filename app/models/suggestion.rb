require "digest"

class Suggestion
  TYPES = %w[
    gift message conversation_topic plan check_in social_reminder event spontaneous repair_focused professional_follow_up
  ].freeze
  HIGH_IMPACT_TYPES = %w[repair_focused professional_follow_up].freeze
  ACTION_KINDS = %w[create_reminder].freeze
  GESTURE_VARIATIONS = %w[low medium high].freeze

  class Reason < Data.define(:label_key, :label_params, :evidence, :certainty, :source)
    CERTAINTIES = %w[confirmed inferred].freeze

    def label
      I18n.t(label_key, **label_params)
    end

    def high_impact_eligible?
      return source.high_impact_automation_allowed? if source.respond_to?(:high_impact_automation_allowed?)
      return !source.confidence.in?(%w[low inferred]) if source.respond_to?(:confidence)

      certainty == "confirmed"
    end
  end

  attr_reader :fingerprint, :suggestion_type, :title_key, :title_params, :detail_key, :detail_params,
    :reasons, :action_kind, :action_attributes, :effort, :variation

  def self.fingerprint_for(relationship_profile_id:, suggestion_type:, source_type:, source_id:, variant: nil)
    parts = [ "v1", relationship_profile_id, suggestion_type, source_type, source_id ]
    parts << variant if variant.present?
    Digest::SHA256.hexdigest(parts.join(":"))
  end

  def initialize(fingerprint:, suggestion_type:, title_key:, title_params:, detail_key:, detail_params:, reasons:,
    action_kind:, action_attributes:, effort: nil, variation: nil)
    raise ArgumentError, "unsupported suggestion type" unless suggestion_type.in?(TYPES)
    raise ArgumentError, "unsupported action kind" unless action_kind.in?(ACTION_KINDS)
    raise ArgumentError, "suggestions require evidence" if reasons.blank?
    if suggestion_type == "spontaneous"
      raise ArgumentError, "unsupported gesture effort" unless effort.in?(GESTURE_VARIATIONS)
      raise ArgumentError, "unsupported gesture variation" unless variation.in?(GESTURE_VARIATIONS)
    end

    @fingerprint = fingerprint
    @suggestion_type = suggestion_type
    @title_key = title_key
    @title_params = title_params
    @detail_key = detail_key
    @detail_params = detail_params
    @reasons = reasons.freeze
    @action_kind = action_kind
    @action_attributes = action_attributes.freeze
    @effort = effort
    @variation = variation
    freeze
  end

  def title
    I18n.t(title_key, **title_params)
  end

  def detail
    I18n.t(detail_key, **detail_params)
  end

  def high_impact?
    suggestion_type.in?(HIGH_IMPACT_TYPES)
  end

  def gesture?
    suggestion_type == "spontaneous"
  end

  def alternative_variation(excluding: [])
    return unless gesture?

    current_index = GESTURE_VARIATIONS.index(variation)
    alternatives = GESTURE_VARIATIONS.rotate(current_index + 1).first(GESTURE_VARIATIONS.size - 1)
    alternatives.find { |candidate| !candidate.in?(excluding) }
  end

  def high_impact_evidence_eligible?
    !high_impact? || reasons.all?(&:high_impact_eligible?)
  end

  def certainty
    reasons.any? { |reason| reason.certainty == "inferred" } ? "inferred" : "confirmed"
  end

  def reminder_attributes
    {
      title:,
      notes: detail,
      reminder_type: action_attributes.fetch(:reminder_type, "check_in"),
      priority: action_attributes.fetch(:priority, "normal")
    }
  end
end
