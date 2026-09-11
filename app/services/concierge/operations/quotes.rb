module Concierge
  module Operations
    class Quotes < ManualPlanRecords
      CLEARABLE_FIELDS = %w[expires_on decision_due_on next_action notes].freeze
      NAMESPACE = "quotes"
      ASSOCIATION = :vendor_quotes
      SEARCH = :scope_details_or_next_action_or_notes_cont
      FIELDS = { vendor_id: :uuid, amount_cents: :integer, currency: :string, scope_details: :string,
        expires_on: :date, decision_due_on: :date, status: VendorQuote::STATUSES, next_action: :string, notes: :string }.freeze
      REQUIRED = %w[vendor_id amount_cents currency scope_details].freeze

      def scope
        records = super
        profile.professional? ? records.where(vendor_id: profile.work_context.selected("vendors").select(:id)) : records
      end

      def create
        vendor = VendorSources.vendor_scope(profile:, user:).find(arguments.fetch("vendor_id"))
        record = user.vendor_quotes.new(record_attributes.except(:vendor_id).merge(event_plan: plan, vendor:))
        authorize!(record, :create)
        record.save_with_context_lock!
        { "record" => record_receipt(record) }
      end

      def update
        authorize!(target, :update)
        target.update_details!(record_attributes, expected_lock_version: arguments.fetch("lock_version"))
        { "record" => record_receipt(target) }
      rescue ActiveRecord::StaleObjectError
        raise RequestConflict
      end

      def destroy
        authorize!(target, :destroy)
        value = record_receipt(target)
        target.remove!
        { "record" => value, "deleted" => true }
      end

      def record_receipt(record)
        receipt(record, title: record.vendor.name, body: record.scope_details, relationship_profile_id: profile.id,
          event_plan_id: plan.id, amount_cents: record.amount_cents, currency: record.currency,
          state: record.display_status, expires_on: record.expires_on&.iso8601, decision_due_on: record.decision_due_on&.iso8601,
          next_action: record.next_action, notes: record.notes, lock_version: record.lock_version, manual_record: true)
      end
    end
  end
end
