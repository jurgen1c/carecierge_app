class SharedItemsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
  before_action -> { response.headers["Cache-Control"] = "no-store" }
  before_action :load_space
  before_action :load_item, except: %i[new create]
  rescue_from ActiveRecord::StaleObjectError, with: :stale_item
  rescue_from ActiveRecord::RecordInvalid, with: :invalid_item

  def new
    @item = @space.shared_items.build(creator: current_user, kind: SharedItem::KINDS.include?(params[:kind]) ? params[:kind] : "plan")
    @item.category = params[:category] if @space.family? && SharedItem::CATEGORIES.include?(params[:category])
    authorize @item
    load_plans
  end

  def create
    @item = SharedSpaces::ChangeItem.call(space: @space, actor: current_user, attributes: item_params)
    saved
  end

  def edit
    authorize @item
    load_plans
  end

  def update
    SharedSpaces::ChangeItem.call(space: @space, actor: current_user, item: @item, attributes: item_params)
    saved
  end

  def destroy
    change(:destroy)
  end

  def complete
    change(:complete, revision: params[:lock_version])
  end

  def claim
    change(:claim, revision: params[:lock_version])
  end

  def respond
    change(:respond, attributes: { attendance: params[:attendance] })
  end

  def subscribe
    change(:subscribe)
  end

  def unsubscribe
    change(:unsubscribe)
  end

  private

  def change(action, **options)
    SharedSpaces::ChangeItem.call(space: @space, actor: current_user, item: @item, action:, **options)
    saved
  end

  def saved
    redirect_to shared_relationship_space_path(@space), notice: t("shared_spaces.saved")
  end

  def load_space
    @space = policy_scope(SharedRelationshipSpace).active.find(params[:shared_relationship_space_id])
  end

  def load_item
    @item = @space.shared_items.find(params[:id])
  end

  def item_params
    params.require(:shared_item).permit(:kind, :title, :details, :editing, :parent_id, :time_zone, :scheduled_local, :lock_version, :category).to_h.symbolize_keys
  end

  def load_plans
    @plans = @space.shared_items.where(kind: "plan").where.not(id: @item.id).order(created_at: :desc).limit(100).to_a
    @plans << @item.parent if @item.parent && @plans.none? { |plan| plan.id == @item.parent_id }
  end

  def invalid_item(error)
    return render plain: t("shared_spaces.unavailable"), status: :unprocessable_content unless error.record.is_a?(SharedItem)
    @item = error.record
    load_plans
    render @item.persisted? ? :edit : :new, status: :unprocessable_content
  end

  def stale_item
    return render plain: t("shared_spaces.stale"), status: :conflict unless action_name == "update"

    @item.reload
    @item.errors.add(:base, t("shared_spaces.stale"))
    load_plans
    render :edit, status: :conflict
  end
end
