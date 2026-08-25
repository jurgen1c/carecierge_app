class PlanTasksController < ApplicationController
  before_action :set_event_plan
  before_action :set_plan_task, except: :create

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def create
    @plan_task = @event_plan.plan_tasks.new(plan_task_params.merge(origin: "manual", source_context: []))
    authorize @plan_task
    mutate_plan do
      @plan_task.position = @event_plan.plan_tasks.maximum(:position).to_i + 1
      @plan_task.save!
    end
    redirect_with_notice("event_plans.plan_tasks.create.notice")
  rescue ActiveRecord::RecordInvalid
    redirect_with_alert("event_plans.plan_tasks.error")
  end

  def update
    mutate_plan { @plan_task.update!(plan_task_params) }
    redirect_with_notice("event_plans.plan_tasks.update.notice")
  rescue ActiveRecord::RecordInvalid
    redirect_with_alert("event_plans.plan_tasks.error")
  end

  def destroy
    mutate_plan { @plan_task.remove_from_plan! }
    redirect_with_notice("event_plans.plan_tasks.destroy.notice")
  end

  def complete
    @plan_task.complete!
    redirect_with_notice("event_plans.plan_tasks.complete.notice")
  end

  def reopen
    @plan_task.reopen!
    redirect_with_notice("event_plans.plan_tasks.reopen.notice")
  end

  private

  def set_event_plan
    @event_plan = policy_scope(EventPlan).for_active_relationships.visible.find(params[:event_plan_id])
    authorize @event_plan, :show?
  end

  def set_plan_task
    @plan_task = @event_plan.plan_tasks.current.find(params[:id])
    authorize @plan_task
  end

  def plan_task_params
    params.require(:plan_task).permit(:phase, :kind, :title, :details, :due_on)
  end

  def mutate_plan
    @event_plan.with_mutation_lock do
      @plan_task.reload if @plan_task&.persisted?
      raise ActiveRecord::RecordNotFound if @plan_task&.superseded?

      yield
      @event_plan.increment!(:generation_version)
    end
  end

  def redirect_with_notice(key)
    redirect_to event_plan_path(@event_plan), notice: t(key)
  end

  def redirect_with_alert(key)
    redirect_to event_plan_path(@event_plan), alert: t(key)
  end
end
