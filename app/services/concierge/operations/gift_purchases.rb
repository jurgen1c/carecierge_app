module Concierge
  module Operations
    class GiftPurchases < Base
      CLEARABLE_FIELDS = %w[budget purchase_by expected_delivery_on follow_up_on shipping_notes constraints follow_up_notes].freeze
      SCOPE_FIELDS = { relationship_profile_id: :uuid, gift_id: :uuid }.freeze
      FIELDS = { budget: :string, currency: :string, purchase_by: :date, expected_delivery_on: :date,
        follow_up_on: :date, purchase_status: GiftPurchasePlan::PURCHASE_STATUSES,
        delivery_status: GiftPurchasePlan::DELIVERY_STATUSES, shipping_notes: :string,
        constraints: :string, follow_up_notes: :string }.freeze
      OPTION_FIELDS = { vendor: :string, url: :string, cost: :string, constraints_checked: :boolean }.freeze

      def self.namespace = "gift_purchases"

      def self.definitions
        [
          define("read", description: "Read manual purchase preparation for a gift, its options and edit version. Nothing is ordered or paid.", fields: SCOPE_FIELDS, required: %w[gift_id], read_only: true),
          define("save", description: "Save gift purchase preparation using its last read edit_version (or new). Budget is a decimal string in the stated currency. Record purchased only if the user reports buying it.",
            fields: SCOPE_FIELDS.merge(FIELDS).merge(version: :string), required: %w[gift_id version]),
          define("add_option", description: "Add one manually supplied purchase option, up to three. Only mark constraints_checked if the user has checked them. Use the last read edit_version.",
            fields: SCOPE_FIELDS.merge(OPTION_FIELDS).merge(version: :string), required: %w[gift_id version vendor]),
          define("remove_option", description: "Preview removing an option by its zero-based position and last read edit_version. Requires confirmation.",
            fields: SCOPE_FIELDS.merge(version: :string, position: :integer), required: %w[gift_id version position], confirmation: true),
          define("add_task", description: "Add purchase preparation to an existing plan for this person, or return its existing linked task. Never purchases anything.",
            fields: SCOPE_FIELDS.merge(event_plan_id: :uuid), required: %w[gift_id event_plan_id]),
          define("remind", description: "Create an independent purchase, delivery or follow-up reminder for this gift at the exact owner-local time the user chooses. Clarify missing time; later logistics edits do not reschedule it.",
            fields: SCOPE_FIELDS.merge(milestone: GiftPurchasePlan::MILESTONES, scheduled_at: :datetime), required: %w[gift_id milestone scheduled_at], capability: "send_reminders")
        ]
      end

      def profile
        record = super
        raise PermissionDenied if record.professional? && !record.professional_gifts_allowed?
        record
      end

      def gift
        @gift ||= Sources.scope(profile:, association: :gifts, turn:).find(arguments.fetch("gift_id"))
      end

      def target = gift.purchase_plan

      def with_record_locks
        gift.lock!
        super
      end

      def read
        authorize!(profile, :show)
        target ? purchase_result(target) : { "edit_version" => "new", "records" => [ Gifts.receipt_for(gift) ] }
      end

      def save
        persist(arguments.slice(*FIELDS.keys.map(&:to_s)))
      end

      def add_option
        options = target&.options&.deep_dup || []
        option = arguments.slice(*OPTION_FIELDS.keys.map(&:to_s))
        option["constraints_checked"] = option["constraints_checked"] ? "1" : "0"
        persist("options" => options + [ option ])
      end

      def remove_option
        raise ActiveRecord::RecordNotFound unless target
        options = target.options.deep_dup
        position = arguments.fetch("position")
        raise InvalidArguments unless position.between?(0, options.length - 1)
        options.delete_at(position)
        persist("options" => options)
      end

      def preview
        ([ gift.name ] + Array(target&.options).map { |option| option.values.join(" · ") } + [ super ]).join("\n")
      end

      def add_task
        authorize!(gift, :update)
        plan = user.event_plans.for_active_relationships.visible.find(arguments.fetch("event_plan_id"))
        raise ActiveRecord::RecordNotFound unless plan.relationship_profile_id == profile.id
        raise ActiveRecord::RecordNotFound unless OccasionSources.plan_visible?(plan, turn:)
        if target&.current_plan_task && !OccasionSources.task_visible?(target.current_plan_task, turn:)
          raise ActiveRecord::RecordNotFound
        end
        authorize!(plan, :update)
        task = ::GiftPurchasePlans::AddTask.call(gift:, event_plan: plan, locale: turn.locale)
        purchase_result(gift.reload.purchase_plan).merge("records" => [ Tasks.receipt_for(task), Plans.new(turn:, arguments: {}).record_receipt(plan.reload) ])
      end

      def purchase_result(record)
        result(record, title: gift.name, body: record.shipping_notes, relationship_profile_id: profile.id,
          gift_id: gift.id, edit_version: record.lock_version.to_s, budget: record.budget&.to_s("F"), currency: record.currency,
          purchase_status: record.purchase_status, delivery_status: record.delivery_status,
          purchase_by: record.purchase_by&.iso8601, expected_delivery_on: record.expected_delivery_on&.iso8601,
          follow_up_on: record.follow_up_on&.iso8601, follow_up_notes: record.follow_up_notes,
          constraints: record.constraints, options: record.options, suggested_option: record.suggested_option, manual_record: true)
      end

      def remind
        raise ActiveRecord::RecordNotFound unless target
        title = I18n.t("gift_purchase_plans.reminder_titles.#{arguments.fetch('milestone')}", locale: turn.locale, name: gift.name)
        Reminders.new(turn:, arguments: { "relationship_profile_id" => profile.id, "title" => title,
          "reminder_type" => "gift_planning", "recurrence" => "none", "scheduled_at" => arguments.fetch("scheduled_at") }).create
      end

      private

      def persist(values)
        authorize!(gift, :update)
        record = ::GiftPurchasePlans::Save.call(gift:, attributes: values, expected_version: arguments.fetch("version"))
        purchase_result(record)
      rescue ActiveRecord::StaleObjectError
        raise RequestConflict
      end
    end
  end
end
