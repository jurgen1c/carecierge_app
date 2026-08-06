class AutomationPermissionOverridesController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  before_action :set_automation_permission, only: %i[update destroy]

  def create
    relationship_profile = current_user.relationship_profiles.kept.find(override_params[:relationship_profile_id])
    permission = current_user.automation_permissions.new(
      capability: override_params[:capability],
      mode: override_params[:mode],
      relationship_profile:
    )
    authorize permission

    AutomationPermissions::Change.call(
      user: current_user,
      actor: current_user,
      capability: permission.capability,
      mode: permission.mode,
      relationship_profile:
    )
    redirect_to_settings(permission.capability, t(".notice"))
  rescue ActiveRecord::RecordInvalid, KeyError
    render plain: t(".error"), status: :unprocessable_content
  end

  def update
    AutomationPermissions::Change.call(
      user: current_user,
      actor: current_user,
      capability: @automation_permission.capability,
      mode: override_params[:mode],
      relationship_profile: @automation_permission.relationship_profile
    )
    redirect_to_settings(@automation_permission.capability, t(".notice"))
  rescue ActiveRecord::RecordInvalid, KeyError
    render plain: t(".error"), status: :unprocessable_content
  end

  def destroy
    capability = @automation_permission.capability
    AutomationPermissions::Change.remove!(permission: @automation_permission, actor: current_user)
    redirect_to_settings(capability, t(".notice"))
  end

  private

  def set_automation_permission
    @automation_permission = current_user
      .automation_permissions
      .relationship_overrides
      .find(params[:id])
    authorize @automation_permission
  end

  def override_params
    params.require(:automation_permission).permit(:capability, :relationship_profile_id, :mode)
  end

  def redirect_to_settings(capability, notice)
    redirect_to edit_automation_permissions_path(capability:), notice:
  end

  def not_found
    head :not_found
  end
end
