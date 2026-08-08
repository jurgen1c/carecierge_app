class DataControlsController < ApplicationController
  def show
    authorize :data_control, :show?
    response.headers["Cache-Control"] = "no-store"
    prepare_data_controls
  end

  private

  def prepare_data_controls
    @relationship_profiles = current_user.relationship_profiles.with_discarded.ordered
  end
end
