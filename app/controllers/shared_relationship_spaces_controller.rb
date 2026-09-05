class SharedRelationshipSpacesController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
  before_action -> { response.headers["Cache-Control"] = "no-store" }
  before_action :load_space, only: %i[show accept destroy]

  def index
    authorize SharedRelationshipSpace
    load_index
    @new_space = SharedRelationshipSpace.new
  end

  def show
    authorize @space
    if @space.active?
      @pagy, @items = pagy(:offset, @space.shared_items.ordered.includes(:creator, :assignee, :parent, :shared_reminder_subscriptions), limit: 20)
    end
  end

  def create
    authorize SharedRelationshipSpace
    @new_space = SharedRelationshipSpace.new(space_params.merge(owner: current_user, invitation_expires_at: 7.days.from_now))
    current_user.with_lock("FOR NO KEY UPDATE") do
      if SharedRelationshipSpace.where(owner: current_user, partner_id: nil).where("invitation_expires_at > ?", Time.current).count >= 5
        @new_space.errors.add(:base, t("shared_spaces.invitation_limit"))
      else
        @new_space.save
      end
    end
    if @new_space.persisted?
      redirect_to shared_relationship_space_path(@new_space), notice: t("shared_spaces.invited")
    else
      load_index
      render :index, status: :unprocessable_content
    end
  end

  def accept
    @space.accept!(current_user)
    redirect_to shared_relationship_space_path(@space), notice: t("shared_spaces.accepted")
  end

  def destroy
    authorize @space
    unless params[:confirm_end] == "1"
      return render plain: t("shared_spaces.confirm_required"), status: :unprocessable_content
    end
    @space.end_sharing!(current_user)
    redirect_to shared_relationship_spaces_path, notice: t("shared_spaces.ended")
  end

  private

  def load_index
    @pagy, @spaces = pagy(:offset, policy_scope(SharedRelationshipSpace).includes(:owner, :partner).order(created_at: :desc, id: :desc), limit: 20)
    @invitations = current_user.confirmed? ? SharedRelationshipSpace.invitations_for(current_user).includes(:owner).order(created_at: :desc).limit(20) : []
  end

  def load_space
    scope = policy_scope(SharedRelationshipSpace)
    scope = scope.or(SharedRelationshipSpace.invitations_for(current_user)) if current_user.confirmed?
    @space = scope.includes(:owner, :partner).find(params[:id])
  end

  def space_params
    params.require(:shared_relationship_space).permit(:title, :invited_email)
  end
end
