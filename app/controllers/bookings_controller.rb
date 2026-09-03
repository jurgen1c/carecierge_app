class BookingsController < ApplicationController
  before_action :set_event_plan, only: %i[new create]
  before_action :set_booking, only: %i[edit update destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def index
    if params[:event_plan_id]
      @event_plan = policy_scope(EventPlan).find(params[:event_plan_id])
      authorize @event_plan, :show?
      @bookings = policy_scope(Booking).where(event_plan: @event_plan).ordered.includes(:reminders).to_a
      @editable = @event_plan.active? && @event_plan.relationship_profile.kept?
    else
      authorize Booking
      @pagy, @bookings = pagy(
        :offset,
        policy_scope(Booking).ordered.includes(:reminders, event_plan: :relationship_profile),
        limit: 20
      )
    end
  end

  def new
    @booking = current_user.bookings.new(
      event_plan: @event_plan,
      booking_kind: params[:booking_kind].presence_in(Booking::BOOKING_KINDS) || "reservation",
      time_zone: booking_time_zone
    )
    authorize @booking
  end

  def create
    @booking = current_user.bookings.new(event_plan: @event_plan)
    assign_booking_attributes(@booking)
    authorize @booking
    Bookings::Save.call(@booking, attributes: {}, locale: I18n.locale)

    redirect_to event_plan_bookings_path(@event_plan), notice: t("bookings.create.notice")
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  def edit
    authorize @booking
    @event_plan = @booking.event_plan
  end

  def update
    authorize @booking
    attributes = normalized_booking_attributes
    expected_lock_version = Integer(attributes.delete(:lock_version), 10)
    Bookings::Save.call(
      @booking,
      attributes:,
      expected_lock_version:,
      locale: I18n.locale
    )

    redirect_to event_plan_bookings_path(@booking.event_plan), notice: t("bookings.update.notice")
  rescue ActiveRecord::StaleObjectError
    redirect_to event_plan_bookings_path(@booking.event_plan), alert: t("bookings.update.changed")
  rescue ActiveRecord::RecordInvalid
    @event_plan = @booking.event_plan
    render :edit, status: :unprocessable_content
  rescue ArgumentError, TypeError, ActionController::ParameterMissing
    raise ActionController::BadRequest, "Invalid lock version"
  end

  def destroy
    authorize @booking
    event_plan = @booking.event_plan
    Bookings::Destroy.call(@booking)

    redirect_to event_plan_bookings_path(event_plan), notice: t("bookings.destroy.notice")
  end

  private

  def set_event_plan
    @event_plan = policy_scope(EventPlan).find(params[:event_plan_id])
  end

  def set_booking
    @booking = policy_scope(Booking).find(params[:id])
  end

  def booking_params
    params.require(:booking).permit(
      :booking_kind,
      :title,
      :provider_name,
      :starts_at,
      :time_zone,
      :location,
      :status,
      :confirmation_details,
      :cancellation_policy,
      :notes,
      :lock_version
    )
  end

  def assign_booking_attributes(booking)
    booking.assign_attributes(normalized_booking_attributes.except(:lock_version))
  end

  def normalized_booking_attributes
    attributes = booking_params.to_h.symbolize_keys
    if attributes.key?(:starts_at)
      local_starts_at = attributes.delete(:starts_at)
      zone_name = attributes[:time_zone].presence || persisted_booking_time_zone || booking_time_zone
      attributes[:time_zone] = zone_name
      attributes[:starts_at] = parse_local_starts_at(local_starts_at, zone_name)
    end
    attributes
  end

  def persisted_booking_time_zone
    @booking.time_zone if @booking&.persisted?
  end

  def parse_local_starts_at(value, zone_name)
    return if value.blank?

    ActiveSupport::TimeZone[zone_name]&.parse(value)
  rescue ArgumentError
    nil
  end

  def booking_time_zone
    current_user.notification_preference&.time_zone.presence || "UTC"
  end

  def not_found = head(:not_found)
end
