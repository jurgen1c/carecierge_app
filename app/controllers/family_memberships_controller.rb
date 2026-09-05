class FamilyMembershipsController < ApplicationController
  before_action -> { response.headers["Cache-Control"] = "no-store" }
  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
  rescue_from ActiveRecord::RecordInvalid, with: -> { render plain: t("family_spaces.invalid_invitation"), status: :unprocessable_content }

  def create
    space = policy_scope(SharedRelationshipSpace).where(mode: "family").find(params[:shared_relationship_space_id])
    raise Pundit::NotAuthorizedError unless space.owner_id == current_user.id
    current_user.with_lock("FOR NO KEY UPDATE") do
      space.with_lock do
        if space.family_memberships.count >= 20
          return render plain: t("family_spaces.member_limit"), status: :unprocessable_content
        end
        space.family_memberships.create!(params.require(:family_membership).permit(:invited_email, :relationship_type).merge(invitation_expires_at: 7.days.from_now))
      end
    end
    redirect_to shared_relationship_space_path(space), notice: t("family_spaces.invited")
  end

  def accept
    membership = FamilyMembership.invitations_for(current_user).find(params[:id])
    membership.accept!(current_user)
    redirect_to shared_relationship_space_path(membership.shared_relationship_space), notice: t("shared_spaces.accepted")
  end

  def destroy
    membership = FamilyMembership.find(params[:id])
    space = membership.shared_relationship_space
    current_user.with_lock("FOR NO KEY UPDATE") do
      space.with_lock do
        membership.reload
        unless space.owner_id == current_user.id || membership.user_id == current_user.id || membership.can_accept?(current_user)
          raise ActiveRecord::RecordNotFound
        end
        unless params[:confirm_leave] == "1"
          return render plain: t("family_spaces.confirm_required"), status: :unprocessable_content
        end
        membership.destroy!
      end
    end
    redirect_to shared_relationship_spaces_path, notice: t("family_spaces.removed")
  end
end
