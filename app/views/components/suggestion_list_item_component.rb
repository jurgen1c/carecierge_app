class SuggestionListItemComponent < ApplicationViewComponent
  option :suggestion
  option :relationship_profile
  option :selected, default: -> { false }

  style do
    base do
      %w[block border-b border-stone-200 px-4 py-4 transition last:border-b-0 hover:bg-stone-50]
    end
    variants do
      certainty do
        confirmed { %w[bg-white] }
        inferred { %w[bg-amber-50] }
      end
      selected do
        yes { %w[ring-2 ring-inset ring-emerald-700] }
        no { [] }
      end
    end
    defaults { { certainty: :confirmed, selected: :no } }
  end

  def type_label
    t("suggestions.types.#{suggestion.suggestion_type}.label")
  end
end
