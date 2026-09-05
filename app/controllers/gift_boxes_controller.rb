class GiftBoxesController < ApplicationController
  before_action :set_profile
  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
  rescue_from ActiveRecord::NestedAttributes::TooManyRecords, with: -> { head :bad_request }

  def index
    @pagy, @boxes = pagy(:offset, @relationship_profile.gift_boxes.order(created_at: :desc, id: :desc), limit: 20)
    @gift_box = @relationship_profile.gift_boxes.new
    authorize @gift_box, :create?
  end

  def show
    @gift_box = @relationship_profile.gift_boxes.includes(:items).find(params[:id])
    authorize @gift_box
  end

  def create
    @gift_box = @relationship_profile.gift_boxes.new(box_params)
    authorize @gift_box
    persist { @gift_box.save! }
  end

  def update
    @gift_box = @relationship_profile.gift_boxes.find(params[:id])
    authorize @gift_box
    attributes = box_params
    raise ActionController::BadRequest if attributes[:lock_version].blank?

    persist do
      @gift_box.lock!
      raise ActiveRecord::StaleObjectError.new(@gift_box, "update") unless @gift_box.lock_version.to_s == attributes[:lock_version].to_s

      @gift_box.assign_attributes(attributes)
      @gift_box.updated_at = Time.current
      @gift_box.save!
    end
  rescue ActiveRecord::StaleObjectError
    redirect_to relationship_profile_gift_box_path(@relationship_profile, @gift_box), alert: t("gift_boxes.changed")
  end

  def destroy
    @gift_box = @relationship_profile.gift_boxes.find(params[:id])
    authorize @gift_box
    with_owner_lock do
      @gift_box.lock!
      @gift_box.destroy!
    end
    redirect_to relationship_profile_gift_boxes_path(@relationship_profile), notice: t("gift_boxes.deleted")
  end

  private

  def set_profile
    @relationship_profile = current_user.relationship_profiles.active.friendly.find(params[:relationship_profile_id])
    response.headers["Cache-Control"] = "no-store"
  end

  def persist
    with_owner_lock { yield }
    redirect_to relationship_profile_gift_box_path(@relationship_profile, @gift_box), notice: t("gift_boxes.saved")
  rescue ActiveRecord::RecordInvalid
    render :show, status: :unprocessable_content
  end

  def with_owner_lock
    current_user.with_lock("FOR NO KEY UPDATE") do
      @relationship_profile.with_lock do
        raise ActiveRecord::RecordNotFound unless @relationship_profile.kept?

        yield
      end
    end
  end

  def box_params
    params.require(:gift_box).permit(:name, :occasion, :budget, :currency, :notes, :constraints, :delivery_on, :lock_version,
      items_attributes: [ :id, :name, :notes, :vendor, :purchase_url, :cost, :purchased, :completed, :_destroy ])
  end
end
