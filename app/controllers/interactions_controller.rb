class InteractionsController < ApplicationController
  before_action :set_relationship_profile
  before_action :set_interaction, only: %i[edit update destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def new
    @interaction = @relationship_profile.interactions.new(occurred_at: Time.current, origin: "manual")
    authorize @interaction
  end

  def edit
  end

  def create
    @interaction = @relationship_profile.interactions.new(interaction_params.merge(origin: "manual"))
    authorize @interaction

    if @interaction.save
      refresh_contact_rhythm(t(".notice"))
    else
      render_form(:new, status: :unprocessable_content)
    end
  end

  def update
    @interaction.assign_attributes(interaction_params)

    if @interaction.save
      refresh_contact_rhythm(t(".notice"))
    else
      render_form(:edit, status: :unprocessable_content)
    end
  end

  def destroy
    @interaction.destroy!
    refresh_contact_rhythm(t(".notice"))
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user.relationship_profiles.friendly.find(params[:relationship_profile_id])
  end

  def set_interaction
    @interaction = @relationship_profile.interactions.find(params[:id])
    authorize @interaction
  end

  def interaction_params
    params.require(:interaction).permit(:interaction_type, :occurred_at, :notes)
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
    frame_id = @interaction.persisted? ? helpers.dom_id(@interaction) : "new_interaction"

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          frame_id,
          partial: "interactions/form_frame",
          locals: { relationship_profile: @relationship_profile, interaction: @interaction }
        ), status:
      end
      format.html { render action, status: }
    end
  end

  def not_found
    head :not_found
  end
end
