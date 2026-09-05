module ExternalProviderActionsHelper
  def provider_context_label(record)
    case record
    when GiftPurchasePlan then record.gift.name
    when VendorQuote then "#{record.vendor.name} — #{record.scope_details.truncate(60)}"
    else record.title
    end
  end

  def provider_context_path(record)
    case record
    when GiftPurchasePlan then relationship_profile_gift_purchase_plan_path(record.gift.relationship_profile_id, record.gift_id)
    when EventPlan then event_plan_path(record)
    when Booking then event_plan_bookings_path(record.event_plan_id)
    when VendorQuote then event_plan_vendor_quotes_path(record.event_plan_id)
    when Reminder then edit_reminder_path(record)
    end
  end

  def provider_context_options(profile, context)
    scope = ExternalProviderAction.context_scope(profile, context)
    scope = scope.includes(:gift) if context == :gift_purchase_plan
    scope = scope.includes(:vendor) if context == :vendor_quote
    records = scope.order(created_at: :desc, id: :desc).to_a
    records.map { |record| [ provider_context_label(record), record.id ] }
  end
end
