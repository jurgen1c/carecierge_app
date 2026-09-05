module GiftBoxes
  class Companions
    CATALOG = {
      "bookmark" => /\b(book|books|reading|libro|libros|lectura)\b/i,
      "coffee_filter" => /\b(coffee|café|cafe)\b/i,
      "plant_label" => /\b(garden|gardening|plants|jardín|jardin|plantas)\b/i
    }.freeze

    def initialize(box)
      @box = box
    end

    def call
      return [] if @box.constraints.present? || (@box.remaining_budget && @box.remaining_budget <= 0)

      preferences = @box.relationship_profile.relationship_preferences.order(:id).to_a
      return [] if preferences.any? { |preference| preference.negative? || preference.constraint? || preference.allergies? || preference.boundaries? || preference.cultural_constraints? }

      CATALOG.filter_map do |key, pattern|
        source = preferences.find { |preference| preference.positive? && preference.confirmed? && "#{preference.key} #{preference.value}".match?(pattern) }
        next unless source
        names = I18n.available_locales.map { |locale| I18n.t("gift_boxes.suggestions.#{key}.name", locale:).downcase }
        next if @box.items.any? { |item| names.include?(item.name.to_s.strip.downcase) }

        { key:, source: }
      end
    end
  end
end
