class ConciergeReceiptComponent < ApplicationViewComponent
  CORRECTABLE_RECORDS = %w[RelationshipProfile MemoryRecord ConversationRecap MoodNote Commitment Desire ImportantDate
    RelationshipPreference RelationshipNote EventPlan PlanTask PersonalTouchItem Interaction Reminder
    Gift GiftPurchasePlan GiftBox Vendor VendorOption VendorQuote Booking DraftRevision].freeze

  option :action
  option :user
  option :read_turn, default: proc { action.turn }

  style :container do
    base { %w[concierge-receipt] }
    variants do
      pending do
        yes { %w[concierge-receipt-pending] }
        no { [] }
      end
    end
  end

  def pending?
    action.state == "awaiting_approval"
  end

  style :decision do
    base { %w[workspace-action] }
    variants do
      choice do
        approve { %w[workspace-action-primary] }
        reject { %w[workspace-action-secondary] }
      end
    end
  end

  style :correction do
    base { %w[workspace-action workspace-action-secondary] }
  end

  def correctable?(source)
    action.state == "succeeded" && !action.result["deleted"] && !action.result["archived"] &&
      action.result.dig("record", "id") == source["id"] && source["record_type"].in?(CORRECTABLE_RECORDS)
  end

  def clarification_available?
    @clarification_available = Concierge::Clarify.available?(action:) unless defined?(@clarification_available)
    @clarification_available
  end

  def operation_label
    I18n.t("concierge.operations.#{action.name}")
  end

  def records
    (Array(action.result["records"]) + [ action.result["record"] ].compact).select do |source|
      Concierge::History.source_current?(source, user:, turn: read_turn)
    end
  end

  def preview
    action.result["preview"].to_s
  end

  def record_details(source)
    details = []
    timestamp = source["starts_at"] || source["scheduled_at"]
    if timestamp
      zone = source["time_zone"].presence || OwnerLocalCalendar.time_zone_for(user:).name
      time = Time.iso8601(timestamp).in_time_zone(zone)
      details << [ I18n.t("concierge.when"), "#{I18n.l(time, format: :long)} (#{time.formatted_offset})" ]
    elsif (date = source["due_on"] || source["starts_on"])
      details << [ I18n.t("concierge.when"), I18n.l(Date.iso8601(date), format: :long) ]
    end
    if source["amount_cents"] && source["currency"]
      amount = helpers.number_with_precision(BigDecimal(source["amount_cents"].to_s) / 100, precision: 2)
      details << [ I18n.t("concierge.recorded_amount"), "#{amount} #{source['currency']}" ]
    end
    details
  end

  def decision_available?
    @decision_available = Concierge::Decide.available?(user:, action:) unless defined?(@decision_available)
    @decision_available
  end
end
