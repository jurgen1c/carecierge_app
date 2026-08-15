class DailyFeedItemComponent < ApplicationViewComponent
  option :item
  option :featured, default: -> { false }
  option :compact, default: -> { false }

  style do
    base do
      %w[border-b border-private-line bg-canvas last:border-b-0]
    end
    variants do
      featured do
        yes { %w[rounded-xl border border-private-line p-5] }
        no { %w[px-4 py-4] }
      end
      compact do
        yes { %w[px-0 py-4] }
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
