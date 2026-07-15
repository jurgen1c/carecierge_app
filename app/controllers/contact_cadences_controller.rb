class ContactCadencesController < ApplicationController
  before_action :set_relationship_profile
  before_action :set_contact_cadence, only: %i[edit update]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def new
    @contact_cadence = @relationship_profile.build_contact_cadence(
      interval_days: ContactCadence.suggested_interval_days_for(@relationship_profile)
    )
    authorize @contact_cadence
  end

  def edit
  end

  def create
    @contact_cadence = @relationship_profile.build_contact_cadence(contact_cadence_params)
    authorize @contact_cadence

    if @contact_cadence.save
      refresh_contact_rhythm(t(".notice"))
    else
      render_form(:new, status: :unprocessable_content)
    end
  end

  def update
    @contact_cadence.assign_attributes(contact_cadence_params)

    if @contact_cadence.save
      refresh_contact_rhythm(t(".notice"))
    else
      render_form(:edit, status: :unprocessable_content)
    end
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user.relationship_profiles.friendly.find(params[:relationship_profile_id])
  end

  def set_contact_cadence
    @contact_cadence = @relationship_profile.contact_cadence || raise(ActiveRecord::RecordNotFound)
    authorize @contact_cadence
  end

  def contact_cadence_params
    params.require(:contact_cadence).permit(:interval_days)
  end

  def refresh_contact_rhythm(message)
    flash.now[:notice] = message
    @relationship_profile.reload
    @interactions = @relationship_profile.interactions.includes(:source).ordered.limit(10).to_a

    respond_to do |format|
      format.turbo_stream { render :refresh }
      format.html { redirect_to relationship_profile_path(@relationship_profile, anchor: "contact_rhythm_section"), notice: message }
    end
  end

  def render_form(action, status:)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "contact_cadence_form",
          partial: "contact_cadences/form_frame",
          locals: { relationship_profile: @relationship_profile, contact_cadence: @contact_cadence }
        ), status:
      end
      format.html { render action, status: }
    end
  end

  def not_found
    head :not_found
  end
end
