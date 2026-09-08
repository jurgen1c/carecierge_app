class DailyFeedItemComponent < ApplicationViewComponent
  option :item
  option :featured, default: -> { false }
  option :compact, default: -> { false }
  option :time_zone, default: -> { Time.zone }

  style do
    base do
      %w[feed-item]
    end
    variants do
      featured do
        yes { %w[feed-item-featured] }
        no { [] }
      end
      compact do
        yes { %w[feed-item-compact] }
        no { [] }
      end
    end
    defaults { { featured: :no, compact: :no } }
  end

  style :certainty do
    base do
      %w[inline-flex rounded-full border border-private-line bg-surface px-2 py-1 text-xs font-semibold]
    end
    variants do
      certainty do
        confirmed { %w[text-primary] }
        inferred { %w[text-quiet-note] }
      end
    end
  end

  style :primary_action do
    base { %w[workspace-action workspace-action-secondary] }
  end

  def scheduled_at
    return unless item.kind.in?(%w[reminder commitment important_date plan_continuation])
    return if item.source.is_a?(Commitment) && item.source.due_on.nil?

    item.sort_at&.in_time_zone(time_zone)
  end

  def scheduled_label
    format = item.source.is_a?(Reminder) ? :short : :long
    l(item.source.is_a?(Reminder) ? scheduled_at : scheduled_at.to_date, format:)
  end

  style :urgency do
    base do
      %w[rounded-full border border-private-line bg-surface px-2 py-1 text-xs font-semibold text-quiet-note]
    end
  end

  def initials
    relationship_name.split.filter_map { |part| part[/[[:alpha:]]/] }.first(2).join.upcase.presence || "C"
  end

  def relationship_name
    item.relationship_profile&.display_name || t("daily_feed.relationship.account")
  end

  def source_action
    case item.action_kind
    when "complete_reminder"
      action(t("daily_feed.actions.complete"), complete_reminder_path(item.source), method: :patch)
    when "complete_commitment"
      action(
        t("daily_feed.actions.complete"),
        complete_relationship_profile_commitment_path(item.relationship_profile, item.source),
        method: :patch
      )
    when "act_on_suggestion"
      action(
        t("daily_feed.actions.act"),
        act_relationship_profile_suggestion_path(item.relationship_profile, item.suggestion.fingerprint),
        method: :post
      )
    when "plan_important_date"
      action(
        t("daily_feed.actions.plan"),
        new_reminder_path(relationship_profile_id: item.relationship_profile.id, important_date_id: item.source.id)
      )
    when "edit_gift"
      action(t("daily_feed.actions.plan_gift"), edit_relationship_profile_gift_path(item.relationship_profile, item.source))
    when "open_message_draft"
      action(t("daily_feed.actions.open_draft"), relationship_profile_path(item.relationship_profile, anchor: "message-drafting"))
    when "edit_commitment"
      action(t("daily_feed.actions.continue_plan"), edit_relationship_profile_commitment_path(item.relationship_profile, item.source))
    when "edit_relationship_goal"
      action(t("daily_feed.actions.review_goal"), edit_relationship_profile_desire_path(item.relationship_profile, item.source))
    end
  end

  private

  def action(label, path, method: nil)
    { label:, path:, method: }
  end
end
