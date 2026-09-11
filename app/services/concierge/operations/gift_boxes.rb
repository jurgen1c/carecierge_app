module Concierge
  module Operations
    class GiftBoxes < Base
      CLEARABLE_FIELDS = %w[budget delivery_on notes constraints cost vendor purchase_url].freeze
      SCOPE_FIELDS = { relationship_profile_id: :uuid }.freeze
      FIELDS = { name: :string, occasion: :string, budget: :string, currency: :string,
        notes: :string, constraints: :string, delivery_on: :date }.freeze
      ITEM_FIELDS = { name: :string, notes: :string, vendor: :string, purchase_url: :string,
        cost: :string, purchased: :boolean, completed: :boolean }.freeze

      def self.namespace = "gift_boxes"

      def self.definitions
        identified = SCOPE_FIELDS.merge(id: :uuid)
        edits = identified.merge(lock_version: :integer)
        [
          define("search", description: "Find this person's manual gift boxes with their items, budgets and edit versions. Follow next_page to continue, including empty encrypted-search pages.", fields: SCOPE_FIELDS.merge(query: :string, page: :integer), read_only: true),
          define("read", description: "Read one gift box and its items.", fields: identified, required: %w[id], read_only: true),
          define("create", description: "Start a manual gift box for an occasion. Money is a decimal string in the stated currency.", fields: SCOPE_FIELDS.merge(FIELDS), required: %w[name occasion]),
          define("update", description: "Update a gift box using its last read lock_version.", fields: edits.merge(FIELDS), required: %w[id lock_version]),
          define("destroy", description: "Preview deleting this box and its items. Requires confirmation.", fields: identified, required: %w[id], confirmation: true),
          define("add_item", description: "Add a manually chosen item to this box using its last read lock_version. Never orders or pays.", fields: edits.merge(ITEM_FIELDS), required: %w[id lock_version name]),
          define("update_item", description: "Correct an identified item using its box's last read lock_version. Only record purchased or completed when the user reports doing so.", fields: edits.merge(ITEM_FIELDS).merge(item_id: :uuid), required: %w[id lock_version item_id]),
          define("remove_item", description: "Preview removing an item using its box's last read lock_version. Requires confirmation.", fields: edits.merge(item_id: :uuid), required: %w[id lock_version item_id], confirmation: true),
          define("suggest_companions", description: "Suggest small companion items from confirmed preferences and the box's constraints. Nothing is added without the user's choice.", fields: identified, required: %w[id], read_only: true),
          define("remind", description: "Create an independent gift-box delivery reminder at the exact owner-local time the user chooses. Clarify missing time; later box edits do not reschedule it.",
            fields: identified.merge(scheduled_at: :datetime), required: %w[id scheduled_at], capability: "send_reminders")
        ]
      end

      def profile
        record = super
        raise PermissionDenied if record.professional? && !record.professional_gifts_allowed?
        record
      end

      def target
        @target ||= scope.find(arguments["id"]) if arguments["id"]
      end

      def scope
        Sources.scope(profile:, association: :gift_boxes, turn:)
      end

      def search
        authorize!(profile, :show)
        matches = SearchRecords.call(scope: scope.includes(:items), predicate: :name_or_occasion_cont,
          query: arguments["query"], page: arguments.fetch("page", 1))
        { "records" => matches.records.map { |box| box_receipt(box) }, "next_page" => matches.next_page }
      end

      def read
        authorize!(target, :show)
        box_result(target)
      end

      def create
        box = profile.gift_boxes.new
        authorize!(box, :create)
        ProfessionalScope.create_and_select!(handler: self, collection: "gift_boxes") do
          ::GiftBoxes::Save.call(box:, attributes: arguments.slice(*FIELDS.keys.map(&:to_s)))
          box
        end
        box_result(box)
      end

      def update
        save(arguments.slice(*FIELDS.keys.map(&:to_s)))
      end

      def destroy
        authorize!(target, :destroy)
        value = box_result(target)
        target.destroy!
        value.merge("deleted" => true)
      end

      def add_item
        save("items_attributes" => [ arguments.slice(*ITEM_FIELDS.keys.map(&:to_s)) ])
      end

      def update_item
        item = target.items.find(arguments.fetch("item_id"))
        save("items_attributes" => [ arguments.slice(*ITEM_FIELDS.keys.map(&:to_s)).merge("id" => item.id) ])
      end

      def remove_item
        item = target.items.find(arguments.fetch("item_id"))
        save("items_attributes" => [ { "id" => item.id, "_destroy" => true } ])
          .merge("superseded" => [ { "record_type" => "GiftBoxItem", "id" => item.id } ])
      end

      def preview
        ([ super ] + Array(target&.items).map { |item| [ item.name, item.notes, item.vendor, item.cost, item.purchase_url ].compact.join(" · ") }).join("\n")
      end

      def suggest_companions
        authorize!(target, :show)
        suggestions = ::GiftBoxes::Companions.new(target).call
        { "suggestions" => suggestions.map do |suggestion|
          { "title" => I18n.t("gift_boxes.suggestions.#{suggestion[:key]}.name", locale: turn.locale),
            "certainty" => "suggested", "source_id" => suggestion[:source].id }
        end, "records" => [ box_receipt(target) ] + suggestions.map { |suggestion| Preferences.new(turn:, arguments: {}).record_receipt(suggestion[:source]) } }
      end

      def box_result(box)
        { "record" => box_receipt(box), "records" => box.items.map { |item| item_receipt(item) } }
      end

      def remind
        authorize!(target, :show)
        title = I18n.t("gift_boxes.reminder_title", locale: turn.locale, name: target.name)
        Reminders.new(turn:, arguments: { "relationship_profile_id" => profile.id, "title" => title,
          "reminder_type" => "gift_planning", "recurrence" => "none", "scheduled_at" => arguments.fetch("scheduled_at") }).create
      end

      def box_receipt(box)
        receipt(box, title: box.name, body: box.notes, occasion: box.occasion, budget: box.budget&.to_s("F"), currency: box.currency,
          constraints: box.constraints, delivery_on: box.delivery_on&.iso8601, lock_version: box.lock_version,
          known_total: box.known_total.to_s, remaining_budget: box.remaining_budget&.to_s("F"),
          items: box.items.map { |item| item_receipt(item) }, manual_record: true)
      end

      def item_receipt(item)
        receipt(item, title: item.name, body: item.notes, relationship_profile_id: profile.id, gift_box_id: item.gift_box_id,
          cost: item.cost&.to_s("F"), vendor: item.vendor, purchase_url: item.purchase_url, purchased: item.purchased, completed: item.completed)
      end

      private

      def save(values)
        authorize!(target, :update)
        ::GiftBoxes::Save.call(box: target, attributes: values, expected_version: arguments.fetch("lock_version").to_s)
        box_result(target)
      rescue ActiveRecord::StaleObjectError
        raise RequestConflict
      end
    end
  end
end
