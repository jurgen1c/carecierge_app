class AutomationPermissionsController < ApplicationController
  def edit
    authorize AutomationPermission, :edit?
    load_settings
  end

  def update
    authorize AutomationPermission, :update?
    AutomationPermissions::UpdateDefaults.call(
      user: current_user,
      actor: current_user,
      modes: automation_permission_modes
    )

    redirect_to edit_automation_permissions_path(capability: selected_capability_param), notice: t(".notice")
  rescue ActiveRecord::RecordInvalid, KeyError
    load_settings
    flash.now[:alert] = t(".error")
    render :edit, status: :unprocessable_content
  end

  private

  def automation_permission_modes
    params.require(:automation_permissions).permit(modes: {}).fetch(:modes, {}).to_h
  end

  def load_settings
    @capabilities = AutomationCapability.all
    account_permissions = current_user.automation_permissions.account_defaults.to_a
    relationship_overrides = current_user
      .automation_permissions
      .relationship_overrides
      .joins(:relationship_profile)
      .merge(current_user.relationship_profiles.kept)
      .includes(:relationship_profile)
      .to_a
    @account_modes = account_permissions
      .to_h { |permission| [ permission.capability, permission.mode ] }
    @overrides_by_capability = relationship_overrides.group_by(&:capability)
    @relationship_profiles = current_user.relationship_profiles.kept.order(:first_name, :last_name).to_a
    @selected_capability = selected_capability
  end

  def selected_capability
    AutomationCapability.fetch(selected_capability_param)
  rescue KeyError
    AutomationCapability.all.first
  end

  def selected_capability_param
    params[:selected_capability].presence || params[:capability].presence || AutomationCapability.all.first.key
  end
end
