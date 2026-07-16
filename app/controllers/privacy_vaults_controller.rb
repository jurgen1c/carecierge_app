class PrivacyVaultsController < ApplicationController
  include PrivacyVaultSession

  rate_limit to: 5, within: 1.minute, by: -> { "#{current_user.id}:#{request.remote_ip}" }, only: :unlock

  before_action :set_relationship_profile

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def show
    authorize @relationship_profile, :show?
    @privacy_vault_unlocked = privacy_vault_unlocked?
    if @privacy_vault_unlocked
      response.headers["Cache-Control"] = "no-store"
      prepare_unlocked_vault
    end
  end

  def unlock
    authorize @relationship_profile, :show?

    password_valid = current_user.with_lock do
      if current_user.valid_password?(unlock_params[:password])
        unlock_privacy_vault!
        true
      else
        current_user.increment!(:privacy_vault_lease_version)
        false
      end
    end

    if password_valid
      VaultAccessEvent.record!(event_type: "unlocked", user: current_user, relationship_profile: @relationship_profile)
      redirect_to relationship_profile_privacy_vault_path(@relationship_profile), notice: t("privacy_vaults.unlock.notice")
    else
      clear_privacy_vault_lease
      VaultAccessEvent.record!(event_type: "unlock_failed", user: current_user, relationship_profile: @relationship_profile)
      @unlock_error = t("privacy_vaults.unlock.invalid_password")
      render :show, status: :unprocessable_content
    end
  end

  def lock
    authorize @relationship_profile, :show?
    current_user.with_lock { current_user.increment!(:privacy_vault_lease_version) }
    clear_privacy_vault_lease
    VaultAccessEvent.record!(event_type: "locked", user: current_user, relationship_profile: @relationship_profile)
    redirect_to relationship_profile_privacy_vault_path(@relationship_profile), notice: t("privacy_vaults.lock.notice")
  end

  def reset_password
    authorize @relationship_profile, :show?
    user = current_user
    user.with_lock { user.increment!(:privacy_vault_lease_version) }
    clear_privacy_vault_lease
    sign_out(user)
    redirect_to new_user_password_path
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user.relationship_profiles.friendly.find(params[:relationship_profile_id])
  end

  def unlock_params
    params.require(:privacy_vault_unlock).permit(:password)
  end

  def prepare_unlocked_vault
    touch_privacy_vault_lease!
    @privacy_vault_items = @relationship_profile.privacy_vault_items.includes(:protectable).ordered.to_a
    @protectable_groups = [
      [ "private_note", @relationship_profile.relationship_notes.includes(:privacy_vault_item).reject(&:vault_protected?) ],
      [ "memory", @relationship_profile.memory_records.includes(:privacy_vault_item).reject(&:vault_protected?) ],
      [ "relationship_detail", @relationship_profile.relationship_field_values.includes(:privacy_vault_item, :template_field).reject(&:vault_protected?) ]
    ]
    VaultAccessEvent.record!(event_type: "viewed", user: current_user, relationship_profile: @relationship_profile)
  end

  def not_found
    head :not_found
  end
end
