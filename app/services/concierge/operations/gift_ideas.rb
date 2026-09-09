module Concierge
  module Operations
    class GiftIdeas < Generated
      FIELDS = { budget_cents: :integer, needed_by: :date, occasion: :string, allow_repeats: :boolean }.freeze

      def self.namespace = "gift_ideas"

      def self.definitions
        [
          define("generate", description: "Prepare up to three gift ideas from authorized relationship context and the user's budget. These are suggestions, not purchases or verified live prices.",
            fields: SCOPE_FIELDS.merge(FIELDS), provider_work: true, capability: "suggest_gifts"),
          define("alternative", description: "Prepare one alternative to an identified generated gift idea, preserving its original budget and occasion.",
            fields: SCOPE_FIELDS.merge(id: :uuid), required: %w[id], provider_work: true, capability: "suggest_gifts"),
          define("search", description: "Read available gift ideas with their rationale and sources. Follow next_page to continue, including empty encrypted-search pages.", fields: SCOPE_FIELDS.merge(query: :string, page: :integer), read_only: true),
          define("read", description: "Read an identified gift idea.", fields: SCOPE_FIELDS.merge(id: :uuid), required: %w[id], read_only: true)
        ] + %w[save dismiss mark_purchased].map do |event|
          define(event, description: "#{event.humanize} a generated gift idea. Mark purchased ONLY to record a purchase the user reports already making; no transaction occurs.",
            fields: SCOPE_FIELDS.merge(id: :uuid), required: %w[id])
        end
      end

      def profile
        record = super
        raise PermissionDenied if record.professional? && !record.professional_gifts_allowed?
        record
      end

      def scope
        profile.gift_recommendations.visible.where(relationship_mode: profile.relationship_mode)
      end

      def target
        @target ||= visible!(scope.find(arguments["id"])) if arguments["id"]
      end

      def generate(on_persist:)
        run_generation(attributes.symbolize_keys, on_persist:)
      end

      def alternative(on_persist:)
        authorize!(target, :update)
        settings = target.attributes.slice(*FIELDS.keys.map(&:to_s)).symbolize_keys
        run_generation(settings.merge(replace: target), on_persist:)
      end

      def search
        authorize!(profile, :show)
        matches = SearchRecords.call(scope:, predicate: :title_or_rationale_cont, query: arguments["query"], page: arguments.fetch("page", 1)) do |record|
          GeneratedSources.visible?(record, turn:)
        end
        { "records" => matches.records.map { |record| recommendation_receipt(record) }, "next_page" => matches.next_page }
      end

      def read
        authorize!(profile, :show)
        { "record" => recommendation_receipt(target) }
      end

      %w[save dismiss mark_purchased].each do |event|
        define_method(event) do
          authorize!(target, event == "dismiss" ? :destroy : :update)
          action = event == "mark_purchased" ? "purchase" : event
          next save_work_gift(action) if profile.professional? && event != "dismiss"

          ::GiftRecommendations::ApplyAction.call(actor: user, recommendation: target, action:)
          result = { "record" => recommendation_receipt(target), "archived" => event == "dismiss" }
          result["records"] = [ Gifts.receipt_for(target.gift) ] if target.gift
          result
        end
      end

      private

      def save_work_gift(action)
        if target.gift
          Sources.scope(profile:, association: :gifts, turn:).find(target.gift.id)
          ::GiftRecommendations::ApplyAction.call(actor: user, recommendation: target, action:)
        else
          ProfessionalScope.create_and_select!(handler: self, collection: "gifts") do
            ::GiftRecommendations::ApplyAction.call(actor: user, recommendation: target, action:)
            target.gift
          end
        end
        # Adding this accepted gift changes the selected work context. Earlier
        # generated ideas must be refreshed before another one can be acted on.
        retired = profile.gift_recommendations.where(id: History.referenced_ids(turn, record_type: "GiftRecommendation")).pluck(:id)
        { "record" => Gifts.receipt_for(target.gift),
          "superseded" => retired.map { |id| { "record_type" => "GiftRecommendation", "id" => id } } }
      end

      def run_generation(settings, on_persist:)
        ::GiftRecommendations::Generate.call(**generation_options, **settings, explicitly_approved: execution_action.decided_at.present?,
          on_persist: ->(records) do
            records.each { |record| GeneratedSources.mark_origin!(record) }
            retired = profile.gift_recommendations.where(status: "dismissed", id: History.referenced_ids(turn, record_type: "GiftRecommendation")).pluck(:id)
            on_persist.call("records" => records.map { |record| recommendation_receipt(record) },
              "superseded" => retired.map { |id| { "record_type" => "GiftRecommendation", "id" => id } })
          end)
      end

      def recommendation_receipt(record)
        receipt(record, title: record.title, body: record.rationale, state: record.status, certainty: "inferred",
          estimated_price_cents: record.estimated_price_cents, vendor: record.vendor, occasion: record.occasion,
          needed_by: record.needed_by&.iso8601, budget_cents: record.budget_cents, sources: record.source_context)
      end
    end
  end
end
