module GiftRecommendations
  class Generate
    MAX_RESULTS = 3
    MAX_PROVIDER_EXCLUDED_TITLES = 40
    MAX_PROVIDER_EXCLUDED_TITLE_LENGTH = 200

    def self.call(
      actor:,
      relationship_profile:,
      budget_cents: nil,
      needed_by: nil,
      occasion: nil,
      allow_repeats: false,
      private_note_ids: [],
      vault_item_ids: [],
      vault_lease: nil,
      explicitly_approved: false,
      locale: I18n.locale,
      replace: nil,
      generator: OpenAiGenerator.new
    )
      new(
        actor:,
        relationship_profile:,
        budget_cents:,
        needed_by:,
        occasion:,
        allow_repeats:,
        private_note_ids:,
        vault_item_ids:,
        vault_lease:,
        explicitly_approved:,
        locale:,
        replace:,
        generator:
      ).call
    end

    def initialize(**attributes)
      attributes.each { |key, value| instance_variable_set("@#{key}", value) }
      @budget_cents = normalize_budget(attributes[:budget_cents])
      @needed_by = normalize_date(attributes[:needed_by])
      @occasion = attributes[:occasion].to_s.squish.presence
      @allow_repeats = ActiveModel::Type::Boolean.new.cast(attributes[:allow_repeats]) || false
      @private_note_ids = Array(attributes[:private_note_ids]).compact_blank.map(&:to_s).uniq
      @vault_item_ids = Array(attributes[:vault_item_ids]).compact_blank.map(&:to_s).uniq
      @locale = attributes[:locale].to_sym
    end

    def call
      generation_version, initial_context, provider_excluded_titles = prepare_generation!
      raw_recommendations = generator.generate(
        sources: initial_context.sources,
        budget_cents:,
        needed_by:,
        occasion:,
        allow_repeats:,
        excluded_titles: provider_excluded_titles,
        locale:,
        count: replace ? 1 : MAX_RESULTS
      )

      actor.with_lock do
        relationship_profile.with_lock do
          validate_request!
          validate_permission!
          validate_vault_access!
          current_context = build_context
          reject_stale_generation!(generation_version:, initial_context:, current_context:)
          recommendations = enrich_recommendations(
            raw_recommendations,
            sources: current_context.sources,
            gift_titles: excluded_gift_titles,
            recommendation_titles: excluded_recommendation_titles
          )
          raise GenerationError, "Gift recommendation response had no usable ideas" if recommendations.empty?

          retire_previous_recommendations!
          persisted = recommendations.map { |attributes| persist_recommendation!(attributes) }
          AuditEvent.record!(
            user: actor,
            actor:,
            action: "gift_recommendation.generated",
            target: relationship_profile,
            metadata: { result: "generated", count: persisted.length }
          )
          persisted
        end
      end
    end

    private

    attr_reader :actor, :relationship_profile, :budget_cents, :needed_by, :occasion, :allow_repeats,
      :private_note_ids, :vault_item_ids, :vault_lease, :explicitly_approved, :locale, :replace, :generator

    def prepare_generation!
      actor.with_lock do
        relationship_profile.with_lock do
          validate_request!
          validate_permission!
          validate_vault_access!
          context = build_context
          validate_selected_sources!(context)
          record_sensitive_access(context.categories)
          relationship_profile.increment!(:gift_recommendation_generation_version)
          [
            relationship_profile.gift_recommendation_generation_version,
            context,
            provider_excluded_titles
          ]
        end
      end
    end

    def validate_request!
      replace&.reload
      raise ActiveRecord::RecordNotFound unless relationship_profile.user_id == actor.id
      raise ActiveRecord::RecordNotFound if relationship_profile.discarded?
      raise ActiveRecord::RecordNotFound if replace && replace.relationship_profile_id != relationship_profile.id
      raise ActiveRecord::RecordNotFound if replace && !replace.generated?
      if budget_cents && !budget_cents.between?(0, Gift::MAX_PRICE_CENTS)
        raise GenerationError, "Gift recommendation budget was invalid"
      end
      raise GenerationError, "Gift recommendation occasion was invalid" if occasion&.length.to_i > GiftRecommendation::MAX_OCCASION_LENGTH
      if needed_by && !needed_by.between?(owner_local_date, GiftRecommendation::MAX_NEEDED_BY)
        raise GenerationError, "Gift recommendation date was invalid"
      end
      raise GenerationError, "Gift recommendation locale was invalid" unless locale.to_s.in?(GiftRecommendation::LOCALES)
    end

    def validate_permission!
      decision = AutomationPermission.decision_for(
        user: actor,
        capability: "suggest_gifts",
        relationship_profile:
      )
      return if decision.permits_execution?(explicitly_approved:)

      raise PermissionDeniedError, "Gift recommendations are not permitted"
    end

    def validate_vault_access!
      return if vault_item_ids.empty?
      return if vault_lease&.active_for?(actor)

      raise VaultAccessError, "Privacy vault access is required"
    end

    def build_context
      ContextBuilder.new(
        relationship_profile:,
        private_note_ids:,
        vault_item_ids:,
        locale:
      ).call
    end

    def validate_selected_sources!(context)
      found_ids = context.sources.map(&:id)
      expected_ids = private_note_ids.map { |id| "private_note:#{id}" } + vault_item_ids.map { |id| "vault:#{id}" }
      raise ActiveRecord::RecordNotFound unless (expected_ids - found_ids).empty?
    end

    def reject_stale_generation!(generation_version:, initial_context:, current_context:)
      return if relationship_profile.gift_recommendation_generation_version == generation_version &&
        initial_context.fingerprint == current_context.fingerprint

      raise GenerationSupersededError, "A newer request or source change superseded these recommendations"
    end

    def excluded_gift_titles
      relationship_profile.gifts.pluck(:name)
    end

    def excluded_recommendation_titles
      relationship_profile.gift_recommendations.where.not(status: "dismissed").pluck(:title)
    end

    def provider_excluded_titles
      return [] if allow_repeats

      relationship_profile.gifts
        .order(created_at: :desc, id: :desc)
        .limit(MAX_PROVIDER_EXCLUDED_TITLES)
        .pluck(:name)
        .map { |title| title.to_s.squish.first(MAX_PROVIDER_EXCLUDED_TITLE_LENGTH) }
    end

    def owner_local_date
      OwnerLocalCalendar.date_for(user: actor)
    end

    def enrich_recommendations(raw_recommendations, sources:, gift_titles:, recommendation_titles:)
      raise GenerationError, "Gift recommendation response was invalid" unless raw_recommendations.is_a?(Array)

      source_by_id = sources.index_by(&:id)
      existing_gift_titles = gift_titles.map { |title| normalize_title(title) }.to_set
      existing_recommendation_titles = recommendation_titles.map { |title| normalize_title(title) }.to_set
      batch_titles = Set.new
      raw_recommendations.first(MAX_RESULTS).filter_map do |raw_recommendation|
        recommendation = raw_recommendation.to_h.deep_stringify_keys
        title = recommendation.fetch("title").to_s.squish
        normalized_title = normalize_title(title)
        next if normalized_title.blank?
        next if repeated_title?(normalized_title, existing_gift_titles:, existing_recommendation_titles:, batch_titles:)

        source_ids = recommendation.fetch("source_ids")
        raise GenerationError, "Gift recommendation response was invalid" unless source_ids.is_a?(Array) && source_ids.present?

        cited_sources = source_ids.uniq.map do |source_id|
          source_by_id[source_id] || raise(GenerationError, "Gift recommendation cited an unknown source")
        end
        estimated_price_cents = recommendation["estimated_price_cents"]
        validate_estimated_price!(estimated_price_cents)
        batch_titles << normalized_title
        {
          title:,
          rationale: recommendation.fetch("rationale").to_s.squish,
          estimated_price_cents:,
          vendor: recommendation["vendor"],
          source_context: cited_sources.map do |source|
            {
              "id" => source.id,
              "label" => source.label,
              "certainty" => source.certainty,
              "sensitive" => source.sensitive
            }
          end
        }
      end
    rescue KeyError, NoMethodError, TypeError
      raise GenerationError, "Gift recommendation response was invalid"
    end

    def validate_estimated_price!(value)
      if value.nil?
        raise GenerationError, "Gift recommendation response was invalid" if budget_cents

        return
      end
      unless value.is_a?(Integer) && value.between?(0, Gift::MAX_PRICE_CENTS)
        raise GenerationError, "Gift recommendation response was invalid"
      end
      raise GenerationError, "Gift recommendation exceeded the requested budget" if budget_cents && value > budget_cents
    end

    def repeated_title?(normalized_title, existing_gift_titles:, existing_recommendation_titles:, batch_titles:)
      return true if batch_titles.include?(normalized_title)
      return true if existing_recommendation_titles.include?(normalized_title)
      return false unless existing_gift_titles.include?(normalized_title)

      !allow_repeats
    end

    def retire_previous_recommendations!
      scope = replace ? relationship_profile.gift_recommendations.where(id: replace.id) : relationship_profile.gift_recommendations.where(status: "generated")
      scope.update_all(status: "dismissed", dismissed_at: Time.current, updated_at: Time.current)
    end

    def persist_recommendation!(attributes)
      relationship_profile.gift_recommendations.create!(
        **attributes,
        user: actor,
        budget_cents:,
        needed_by:,
        occasion:,
        allow_repeats:,
        include_private_notes: private_note_ids.any?,
        include_vault_context: vault_item_ids.any?,
        locale: locale.to_s,
        generated_at: Time.current
      )
    end

    def record_sensitive_access(categories)
      return if (categories & %w[private_notes vault]).empty?

      AuditEvent.record!(
        user: actor,
        actor:,
        action: "sensitive_record.accessed",
        target: relationship_profile,
        metadata: { result: "gift_recommendation" }
      )
      return unless categories.include?("vault")

      VaultAccessEvent.record_safely(event_type: "viewed", user: actor, relationship_profile:)
    end

    def normalize_budget(value)
      return if value.blank?

      Integer(value)
    rescue ArgumentError, TypeError
      -1
    end

    def normalize_date(value)
      return if value.blank?
      return value if value.is_a?(Date)

      Date.iso8601(value.to_s)
    rescue Date::Error
      Date.new(1, 1, 1)
    end

    def normalize_title(value)
      Gift.normalized_duplicate_name(value)
    end
  end
end
