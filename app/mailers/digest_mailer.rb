class DigestMailer < ApplicationMailer
  helper_method :digest_item_title, :digest_item_timing, :digest_item_url, :digest_item_planning_prompt

  def summary
    @recipient = params.fetch(:recipient)
    @digest = params[:digest] || snapshot_digest || compose_digest(params.fetch(:record))

    mail to: @recipient.email, subject: I18n.t("digest_mailer.summary.subject.#{@digest.mode}")
  end

  def snapshot_digest
    Digests::Snapshot.load(params[:digest_snapshot]) if params[:digest_snapshot]
  end

  def compose_digest(delivery)
    Digests::Compose.call(
      user: delivery.user,
      as_of: delivery.scheduled_for.in_time_zone(delivery.user.notification_preference.time_zone),
      mode: delivery.mode
    )
  end

  def digest_item_timing(item)
    case item.kind
    when :commitment
      key = item.overdue ? "overdue" : "due"
      I18n.t("digest_mailer.summary.items.commitment.#{key}", count: (item.due_at.to_date - @digest.as_of.to_date).to_i.abs, date: I18n.l(item.due_at.to_date, format: :commitment_due_on))
    when :upcoming_date
      I18n.l(item.due_at.to_date, format: :important_date)
    when :planning_prompt
      digest_item_planning_prompt(item)
    when :check_in
      I18n.t("digest_mailer.summary.items.check_in")
    end
  end

  def digest_item_url(item)
    profile = item.respond_to?(:relationship_profile) ? item.relationship_profile : item.relationship_profile_id
    relationship_profile_url(profile)
  end

  def digest_item_planning_prompt(item)
    return item.planning_prompt if item.respond_to?(:planning_prompt)

    item.record.planning_prompt(as_of: @digest.as_of.to_date)
  end

  def digest_item_title(item)
    return item.title unless item.kind == :check_in

    I18n.t("digests.items.check_in_title", name: item.relationship_name)
  end
end
