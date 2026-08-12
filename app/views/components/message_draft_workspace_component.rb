class MessageDraftWorkspaceComponent < ApplicationViewComponent
  option :relationship_profile
  option :message_draft, default: -> { nil }
  option :revisions, default: -> { [] }
  option :revisions_pagy, default: -> { nil }
  option :context_categories, default: -> { [] }
  option :private_notes_available, default: -> { false }
  option :vault_items_available, default: -> { false }
  option :vault_unlocked, default: -> { false }

  style :layout do
    base { %w[grid lg:grid-cols-[minmax(16rem,0.72fr)_minmax(0,1.28fr)]] }
  end

  style :primary_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg bg-primary px-5 py-3
        text-sm font-semibold text-canvas transition hover:bg-primary-hover
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary
        disabled:cursor-not-allowed disabled:bg-stone-300 disabled:text-stone-600
      ]
    end
  end

  style :secondary_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg border border-stone-300 bg-canvas px-5 py-3
        text-sm font-semibold text-ink transition hover:bg-stone-100
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary
        disabled:cursor-not-allowed disabled:bg-stone-100 disabled:text-stone-500
      ]
    end
  end

  style :danger_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg border border-danger-border bg-canvas px-4 py-2
        text-sm font-semibold text-danger-ink transition hover:bg-danger-surface
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-danger-ink
      ]
    end
  end

  def draft_type
    message_draft&.draft_type || "birthday"
  end

  def tone
    message_draft&.tone || "warm"
  end

  def content
    current_revision&.content.to_s
  end

  def current_revision?(revision)
    current_revision&.id == revision.id
  end

  def revision_page_path(page)
    relationship_profile_path(relationship_profile, draft_page: page, anchor: "message-drafting")
  end

  def context_label(category)
    t("message_drafts.context.categories.#{category}")
  end

  private

  def current_revision
    @current_revision ||= message_draft&.current_revision
  end
end
