class PrivacyVaultItemsController < ApplicationController
  include PrivacyVaultSession

  before_action :set_relationship_profile
  before_action :require_privacy_vault_unlock
  before_action :set_privacy_vault_item, only: %i[update destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def create
    protectable = find_protectable
    item = @relationship_profile.privacy_vault_items.new(protectable:)
    authorize item
    PrivacyVault::Protect.call(actor: current_user, protectable:)

    redirect_to relationship_profile_privacy_vault_path(@relationship_profile), notice: t("privacy_vault_items.create.notice")
  rescue ActiveRecord::RecordInvalid => error
    redirect_to relationship_profile_privacy_vault_path(@relationship_profile), alert: error.record.errors.full_messages.to_sentence
  end

  def update
    authorize @privacy_vault_item
    PrivacyVault::ChangeSuggestionUsage.call(
      actor: current_user,
      item: @privacy_vault_item,
      suggestion_usage: item_params.fetch(:suggestion_usage)
    )

    redirect_to relationship_profile_privacy_vault_path(@relationship_profile), notice: t("privacy_vault_items.update.notice")
  rescue ActiveRecord::RecordInvalid => error
    redirect_to relationship_profile_privacy_vault_path(@relationship_profile), alert: error.record.errors.full_messages.to_sentence
  end

  def destroy
    authorize @privacy_vault_item
    PrivacyVault::Restore.call(actor: current_user, item: @privacy_vault_item)

    redirect_to relationship_profile_privacy_vault_path(@relationship_profile), notice: t("privacy_vault_items.destroy.notice")
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user.relationship_profiles.friendly.find(params[:relationship_profile_id])
  end

  def set_privacy_vault_item
    @privacy_vault_item = @relationship_profile.privacy_vault_items.find(params[:id])
  end

  def item_params
    params.require(:privacy_vault_item).permit(:protectable_type, :protectable_id, :suggestion_usage)
  end

  def find_protectable
    id = item_params.fetch(:protectable_id)

    case item_params.fetch(:protectable_type)
    when "MemoryRecord"
      @relationship_profile.memory_records.includes(:privacy_vault_item).find(id)
    when "RelationshipNote"
      @relationship_profile.relationship_notes.includes(:privacy_vault_item).find(id)
    when "RelationshipFieldValue"
      @relationship_profile.relationship_field_values.includes(:privacy_vault_item).find(id)
    else
      raise ActiveRecord::RecordNotFound
    end.tap do |protectable|
      raise ActiveRecord::RecordNotFound if protectable.vault_protected?
    end
  end

  def not_found
    head :not_found
  end
end
