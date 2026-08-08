class ExtractedMemoriesController < ApplicationController
  before_action :set_relationship_profile
  before_action :set_extracted_memory

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def review
    MemoryExtractions::Review.call(
      extracted_memory: @extracted_memory,
      reviewer: current_user,
      decision: review_params[:decision],
      corrected_title: review_params[:corrected_title],
      corrected_body: review_params[:corrected_body]
    )

    redirect_to relationship_profile_path(@relationship_profile, memory_proposal: next_pending_id, anchor: "memory-review"),
      notice: t(".notice.#{review_params[:decision]}")
  rescue ActiveRecord::RecordInvalid
    redirect_to relationship_profile_path(@relationship_profile, memory_proposal: @extracted_memory.id, anchor: "memory-review"),
      alert: t(".invalid_correction")
  rescue ArgumentError
    redirect_to relationship_profile_path(@relationship_profile, memory_proposal: @extracted_memory.id, anchor: "memory-review"),
      alert: t(".invalid_decision")
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user.relationship_profiles.friendly.find(params[:relationship_profile_id])
  end

  def set_extracted_memory
    @extracted_memory = @relationship_profile.extracted_memories.find(params[:id])
    authorize @extracted_memory, :review?
  end

  def review_params
    params.require(:extracted_memory).permit(:decision, :corrected_title, :corrected_body)
  end

  def next_pending_id
    @relationship_profile.extracted_memories.pending_review.where.not(id: @extracted_memory.id).pick(:id)
  end
end
