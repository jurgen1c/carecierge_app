class Users::RegistrationsController < Devise::RegistrationsController
  def destroy
    redirect_to data_control_path,
      alert: I18n.t("data_deletions.errors.use_data_controls"),
      status: :see_other
  end
end
