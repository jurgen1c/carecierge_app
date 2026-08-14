class SocialContextLedgerComponent < ApplicationViewComponent
  include ActionText::ContentHelper
  include Lexxy::TagHelper

  option :relationship_profile
  option :notes, default: -> { [] }
  option :notes_pagy, default: -> { nil }
  option :new_note
  option :analysis_permission
  option :editable, default: -> { true }

  style :ledger do
    base { %w[overflow-hidden rounded-2xl border border-private-line bg-canvas shadow-sm shadow-stone-200/40] }
  end

  style :primary_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg bg-primary px-4 py-2
        text-sm font-semibold text-canvas transition hover:bg-primary-hover
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary
      ]
    end
  end

  style :secondary_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg border border-stone-300 bg-canvas px-4 py-2
        text-sm font-semibold text-ink transition hover:bg-stone-100
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary
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

  def permission_enabled?
    analysis_permission.enabled?
  end

  def analysis_button_label
    t("social_context_notes.actions.analyze")
  end

  def analysis_permission_path
    edit_automation_permissions_path(
      capability: "analyze_uploaded_social_content",
      anchor: "capability-panel-analyze_uploaded_social_content"
    )
  end

  def status_label(note)
    t("social_context_notes.statuses.#{note.interpretation_status}")
  end

  def update_form_id(note)
    dom_id(note, :social_context_update)
  end

  def social_context_field_id(note, field)
    suffix = note.persisted? ? note.id : "new"
    "social_context_note_#{suffix}_#{field}"
  end

  def error_summary_id(note)
    "#{social_context_field_id(note, :body)}_errors"
  end

  def suggested_use_field_id(note, use)
    "#{social_context_field_id(note, :suggested_uses)}_#{use}"
  end

  def note_form_path(note)
    if note.persisted?
      return relationship_profile_social_context_note_path(
        relationship_profile,
        note,
        social_context_page: current_page
      )
    end

    relationship_profile_social_context_notes_path(relationship_profile, social_context_page: current_page)
  end

  def note_action_path(note)
    relationship_profile_social_context_note_path(
      relationship_profile,
      note,
      social_context_page: current_page
    )
  end

  def notes_page_path(page)
    relationship_profile_path(relationship_profile, social_context_page: page, anchor: "social-context")
  end

  def current_page
    notes_pagy&.page
  end

  def social_context_editor_data
    {
      direct_upload_url: social_context_direct_uploads_path,
      blob_url_template: social_context_screenshot_path(signed_id: ":signed_id", filename: ":filename")
    }
  end

  def main_app
    helpers.main_app
  end
end
