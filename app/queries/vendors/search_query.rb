module Vendors
  class SearchQuery < ApplicationQuery
    attr_reader :query, :category, :location, :occasion_type, :preference, :maximum_budget, :timing

    def initialize(relation = Vendor.all, params:, event_plan: nil)
      super(relation)
      values = params.to_h.symbolize_keys
      @query = bounded(values[:query], Vendor::MAX_NAME_LENGTH)
      @category = values[:category].presence_in(Vendor::CATEGORIES)
      @location = bounded(values[:location], Vendor::MAX_LOCATION_LENGTH)
      @occasion_type = if values.key?(:occasion_type)
        values[:occasion_type].presence_in(EventPlan::OCCASION_TYPES)
      else
        event_plan&.occasion_type
      end
      @preference = bounded(values[:preference], Vendor::MAX_TAG_LENGTH)&.downcase
      @maximum_budget_cents = if values.key?(:maximum_budget)
        parse_budget(values[:maximum_budget])
      else
        event_plan&.budget_cents
      end
      @maximum_budget = formatted_budget(@maximum_budget_cents)
      @timing = bounded(values[:timing], Vendor::MAX_AVAILABILITY_LENGTH)
    end

    def resolve
      scoped = relation
      scoped = text_search(scoped)
      scoped = scoped.where(category:) if category
      scoped = scoped.where("lower(vendors.location) LIKE ?", like(location)) if location
      scoped = scoped.where("vendors.occasion_types @> ?", [ occasion_type ].to_json) if occasion_type
      scoped = scoped.where("vendors.preference_tags @> ?", [ preference ].to_json) if preference
      scoped = scoped.where("vendors.minimum_price_cents IS NULL OR vendors.minimum_price_cents <= ?", @maximum_budget_cents) if @maximum_budget_cents
      scoped = scoped.where("lower(vendors.availability) LIKE ?", like(timing)) if timing
      scoped.ordered
    end

    def active? = [ query, category, location, occasion_type, preference, maximum_budget, timing ].any?(&:present?)

    def explanation_for(vendor)
      return vendor.fit_notes if vendor.fit_notes.present?

      matches = []
      matches << I18n.t("vendors.matches.category") if category && vendor.category == category
      matches << I18n.t("vendors.matches.location") if location && vendor.location.to_s.downcase.include?(location.downcase)
      matches << I18n.t("vendors.matches.occasion") if occasion_type && occasion_type.in?(vendor.occasion_types)
      matches << I18n.t("vendors.matches.preference") if preference && preference.in?(vendor.preference_tags)
      if @maximum_budget_cents && vendor.minimum_price_cents.present? && vendor.minimum_price_cents <= @maximum_budget_cents
        matches << I18n.t("vendors.matches.budget")
      end
      matches << I18n.t("vendors.matches.timing") if timing && vendor.availability.to_s.downcase.include?(timing.downcase)

      I18n.t("vendors.matches.summary", matches: localized_sentence(matches).presence || I18n.t("vendors.matches.saved"))
    end

    private

    def text_search(scope)
      return scope if query.blank?

      term = like(query)
      text_matches = scope.where(
        "lower(vendors.name) LIKE :term OR lower(vendors.category) LIKE :term OR " \
          "lower(vendors.location) LIKE :term OR lower(vendors.availability) LIKE :term OR lower(vendors.source_name) LIKE :term",
        term:
      )
      matching_categories = Vendor::CATEGORIES.select do |value|
        I18n.t("vendors.categories.#{value}").downcase.include?(query.downcase)
      end

      matching_categories.empty? ? text_matches : text_matches.or(scope.where(category: matching_categories))
    end

    def bounded(value, maximum)
      value.to_s.squish.first(maximum).presence
    end

    def like(value) = "%#{ActiveRecord::Base.sanitize_sql_like(value.downcase)}%"

    def parse_budget(value)
      return if value.blank?

      decimal = BigDecimal(value.to_s)
      return unless decimal.finite? && decimal >= 0 && decimal * 100 <= Vendor::MAX_PRICE_CENTS

      (decimal * 100).round
    rescue ArgumentError
      nil
    end

    def formatted_budget(cents)
      format("%.2f", BigDecimal(cents.to_s) / 100) if cents
    end

    def localized_sentence(items)
      items.to_sentence(
        words_connector: I18n.t("vendors.matches.join.words"),
        two_words_connector: I18n.t("vendors.matches.join.two"),
        last_word_connector: I18n.t("vendors.matches.join.last")
      )
    end
  end
end
