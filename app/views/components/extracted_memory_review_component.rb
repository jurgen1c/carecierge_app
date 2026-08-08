class ExtractedMemoryReviewComponent < ApplicationViewComponent
  option :extracted_memory
  option :relationship_profile

  style :badge do
    base { %w[inline-flex w-fit items-center rounded-full px-3 py-1 text-xs font-semibold] }
    variants do
      tone do
        category { %w[bg-emerald-50 text-emerald-900] }
        high { %w[bg-emerald-50 text-emerald-900] }
        medium { %w[bg-amber-50 text-amber-950] }
        low { %w[bg-stone-100 text-stone-800] }
        inferred { %w[bg-stone-100 text-stone-800] }
      end
    end
    defaults { { tone: :category } }
  end

  def review_path
    review_relationship_profile_extracted_memory_path(relationship_profile, extracted_memory)
  end

  def confidence_tone
    extracted_memory.confidence.to_sym
  end
end
