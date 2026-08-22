class PersonalTouchChecklistsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def create
    moment = selected_moment
    checklist = moment.personal_touch_checklist || moment.build_personal_touch_checklist(relationship_profile: moment.relationship_profile)
    authorize checklist

    checklist = PersonalTouchChecklists::Create.call(actor: current_user, moment:, locale: I18n.locale)
    redirect_to moment_path(checklist), notice: t("personal_touch_checklists.create.notice")
  end

  private

  def selected_moment
    return selected_event_plan if params[:event_plan_id].present?

    profile = current_user.relationship_profiles.active.friendly.find(params[:relationship_profile_id])
    profile.important_dates.find(params[:important_date_id])
  end

  def selected_event_plan
    policy_scope(EventPlan).for_active_relationships.visible.find(params[:event_plan_id])
  end

  def moment_path(checklist)
    if checklist.event_plan
      event_plan_path(checklist.event_plan, anchor: "personal-touch-checklist")
    else
      relationship_profile_path(
        checklist.relationship_profile,
        anchor: "personal-touch-#{checklist.important_date_id}"
      )
    end
  end
end
