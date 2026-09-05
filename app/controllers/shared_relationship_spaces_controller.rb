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
    @family_memberships = @space.family_memberships.includes(:user).order(:created_at) if @space.family?
    if @space.active?
      @pagy, @items = pagy(:offset, filtered_items.includes(:creator, :assignee, :parent, :shared_reminder_subscriptions, family_responses: :user), limit: 20)
    end
  end

  def create
    authorize SharedRelationshipSpace
    @new_space = SharedRelationshipSpace.new(space_params.merge(owner: current_user, invitation_expires_at: 7.days.from_now))
    current_user.with_lock("FOR NO KEY UPDATE") do
      if !@new_space.family? && SharedRelationshipSpace.where(owner: current_user, mode: "couple", partner_id: nil).where("invitation_expires_at > ?", Time.current).count >= 5
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
    @family_invitations = current_user.confirmed? ? FamilyMembership.invitations_for(current_user).includes(shared_relationship_space: :owner).order(created_at: :desc).limit(20) : []
    @invitations = current_user.confirmed? ? SharedRelationshipSpace.invitations_for(current_user).includes(:owner).order(created_at: :desc).limit(20) : []
  end

  def load_space
    scope = policy_scope(SharedRelationshipSpace)
    scope = scope.or(SharedRelationshipSpace.invitations_for(current_user)) if current_user.confirmed?
    @space = scope.includes(:owner, :partner).find(params[:id])
  end

  def filtered_items
    items = @space.shared_items.ordered
    return items unless @space.family?

    items = items.where(category: params[:category]) if SharedItem::CATEGORIES.include?(params[:category])
    case params[:view]
    when "calendar" then items.where.not(due_at: nil).where(completed_at: nil)
    when "mine" then items.where(assignee: current_user, completed_at: nil)
    else items
    end
  end

  def space_params
    params.require(:shared_relationship_space).permit(:title, :invited_email, :mode)
  end
end
