class PersonalTouchItemsController < ApplicationController
  before_action :set_checklist
  before_action :set_item, except: :create

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
  rescue_from ActiveRecord::RecordInvalid, with: -> { redirect_with_alert("personal_touch_checklists.items.error") }

  def create
    @item = @checklist.personal_touch_items.new(item_params.merge(origin: "manual", status: "active", source_context: []))
    authorize @item
    track("personal_touch_item.created") do
      @checklist.with_mutation_lock do
        @item.position = (@checklist.personal_touch_items.maximum(:position) || -1) + 1
        @item.save!
      end
    end
    redirect_with_notice("personal_touch_checklists.items.create.notice")
  end

  def complete
    track("personal_touch_item.completed") { @item.complete! }
    redirect_with_notice("personal_touch_checklists.items.complete.notice")
  end

  def reopen
    track("personal_touch_item.reopened") { @item.reopen! }
    redirect_with_notice("personal_touch_checklists.items.reopen.notice")
  end

  def dismiss
    track("personal_touch_item.dismissed") { @item.dismiss! }
    redirect_with_notice("personal_touch_checklists.items.dismiss.notice")
  end

  def move_up
    track("personal_touch_item.reordered") { @item.move_up! }
    redirect_to_moment
  end

  def move_down
    track("personal_touch_item.reordered") { @item.move_down! }
    redirect_to_moment
  end

  private

  def set_checklist
    @checklist = policy_scope(PersonalTouchChecklist)
      .includes(:event_plan, :important_date, :relationship_profile)
      .find(params[:personal_touch_checklist_id])
    authorize @checklist, :update?
  end

  def set_item
    @item = @checklist.personal_touch_items.find(params[:id])
    authorize @item
  end

  def item_params
    params.require(:personal_touch_item).permit(:category, :title, :details)
  end

  def track(action, &mutation)
    AuditEvents::Track.call(
      user: current_user,
      actor: current_user,
      action:,
      target: @checklist.relationship_profile,
      &mutation
    )
  end

  def redirect_with_notice(key)
    redirect_to_moment(notice: t(key))
  end

  def redirect_with_alert(key)
    redirect_to_moment(alert: t(key))
  end

  def redirect_to_moment(**flash)
    path = if @checklist.event_plan
      event_plan_path(@checklist.event_plan, anchor: "personal-touch-checklist")
    else
      relationship_profile_path(
        @checklist.relationship_profile,
        anchor: "personal-touch-#{@checklist.important_date_id}"
      )
    end
    redirect_to path, **flash
  end
end
