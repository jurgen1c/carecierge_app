module GiftRecommendations
  class ApplyAction
    ACTIONS = %w[dismiss save purchase].freeze

    def self.call(actor:, recommendation:, action:, at: Time.current)
      new(actor:, recommendation:, action:, at:).call
    end

    def initialize(actor:, recommendation:, action:, at:)
      @actor = actor
      @recommendation = recommendation
      @action = action.to_s
      @at = at
    end

    def call
      raise ArgumentError, "unsupported gift recommendation action" unless action.in?(ACTIONS)

      actor.with_lock do
        recommendation.relationship_profile.with_lock do
          recommendation.lock!
          validate_owner!
          return recommendation if completed_action?
          raise ActiveRecord::RecordInvalid, recommendation unless recommendation.generated?

          gift = create_gift if action.in?(%w[save purchase])
          recommendation.update!(transition_attributes(gift:))
          recommendation.relationship_profile.increment!(:gift_recommendation_generation_version)
          AuditEvent.record!(
            user: actor,
            actor:,
            action: "gift_recommendation.#{audit_action}",
            target: recommendation.relationship_profile,
            metadata: { result: recommendation.status }
          )
          recommendation
        end
      end
    end

    private

    attr_reader :actor, :recommendation, :action, :at

    def validate_owner!
      return if recommendation.user_id == actor.id && recommendation.relationship_profile.user_id == actor.id

      raise ActiveRecord::RecordNotFound
    end

    def completed_action?
      (action == "dismiss" && recommendation.dismissed?) ||
        (action == "save" && recommendation.saved?) ||
        (action == "purchase" && recommendation.purchased?)
    end

    def create_gift
      recommendation.relationship_profile.gifts.create!(
        name: recommendation.title,
        status: action == "purchase" ? "planned" : "idea",
        occasion: recommendation.occasion,
        price_cents: recommendation.estimated_price_cents,
        vendor: recommendation.vendor,
        notes: recommendation.rationale
      )
    end

    def transition_attributes(gift:)
      case action
      when "dismiss" then { status: "dismissed", dismissed_at: at }
      when "save" then { status: "saved", saved_at: at, gift: }
      when "purchase" then { status: "purchased", purchased_at: at, gift: }
      end
    end

    def audit_action
      { "dismiss" => "dismissed", "save" => "saved", "purchase" => "purchased" }.fetch(action)
    end
  end
end
