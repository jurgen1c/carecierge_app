require "rails_helper"

RSpec.describe "Bookings", type: :request do
  let(:valid_attributes) do
    {
      booking_kind: "reservation",
      title: "Dinner reservation",
      provider_name: "Casa Verde",
      starts_at: "2026-09-20T19:00",
      time_zone: "America/Costa_Rica",
      location: "Main dining room",
      status: "requested",
      confirmation_details: "Request sent by phone",
      cancellation_policy: "Cancel by noon the day before",
      notes: "Ask for a quiet table"
    }
  end

  it "creates and lists a manual booking for an owned active plan" do
    plan = create(:event_plan)
    sign_in plan.user

    expect do
      post event_plan_bookings_path(plan), params: { booking: valid_attributes }
    end.to change(Booking, :count).by(1)

    booking = plan.bookings.reload.sole
    expect(booking).to have_attributes(
      booking_kind: "reservation",
      title: "Dinner reservation",
      provider_name: "Casa Verde",
      status: "requested",
      time_zone: "America/Costa_Rica"
    )
    expect(response).to redirect_to(event_plan_bookings_path(plan))

    get event_plan_bookings_path(plan)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Bookings", "Dinner reservation", "Casa Verde", "Requested", "Manual tracking only")
    expect(response.body).to include("Set confirmation reminder", "Set deposit reminder", "Set arrival reminder", "Set change reminder")
    expect(response.body).not_to include("Book now", "Pay deposit")
  end

  it "persists the owner time zone used to parse a create request without one" do
    plan = create(:event_plan)
    create(
      :notification_preference,
      user: plan.user,
      time_zone: "America/Costa_Rica",
      time_zone_configured: true
    )
    sign_in plan.user

    post event_plan_bookings_path(plan), params: {
      booking: valid_attributes.except(:time_zone)
    }

    expect(response).to redirect_to(event_plan_bookings_path(plan))
    expect(plan.bookings.reload.sole).to have_attributes(
      time_zone: "America/Costa_Rica",
      starts_at: Time.utc(2026, 9, 21, 1)
    )
  end

  it "updates a booking and derived plan state with the rendered revision" do
    booking = create(:booking, status: "requested")
    Bookings::Save.call(booking, attributes: {}, locale: :en)
    sign_in booking.user

    patch booking_path(booking), params: {
      booking: valid_attributes.merge(title: "Confirmed dinner", status: "confirmed", lock_version: booking.lock_version)
    }

    expect(response).to redirect_to(event_plan_bookings_path(booking.event_plan))
    expect(booking.reload).to have_attributes(title: "Confirmed dinner", status: "confirmed")
    expect(booking.plan_task).to be_completed
    expect(booking.timeline_entry).to have_attributes(title: "Booking status", body: "Confirmed")
  end

  it "preserves scheduling fields omitted from a partial update" do
    booking = create(:booking, starts_at: Time.utc(2026, 9, 20, 1), time_zone: "America/Costa_Rica")
    Bookings::Save.call(booking, attributes: {}, locale: :en)
    sign_in booking.user

    patch booking_path(booking), params: {
      booking: { notes: "Updated alone", lock_version: booking.lock_version }
    }

    expect(response).to redirect_to(event_plan_bookings_path(booking.event_plan))
    expect(booking.reload).to have_attributes(
      notes: "Updated alone",
      starts_at: Time.utc(2026, 9, 20, 1),
      time_zone: "America/Costa_Rica"
    )
  end

  it "redisplays an invalid partial time-zone update instead of raising" do
    booking = create(:booking, starts_at: Time.utc(2026, 9, 20, 1), time_zone: "America/Costa_Rica")
    Bookings::Save.call(booking, attributes: {}, locale: :en)
    sign_in booking.user

    patch booking_path(booking), params: {
      booking: { time_zone: "Mars/Olympus", lock_version: booking.lock_version }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Time zone is not recognized")
    expect(booking.reload.time_zone).to eq("America/Costa_Rica")
  end

  it "retains an IANA time zone and prevents private form snapshots" do
    booking = create(:booking, time_zone: "America/Costa_Rica")
    Bookings::Save.call(booking, attributes: {}, locale: :en)
    sign_in booking.user

    get edit_booking_path(booking)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css("select[name='booking[time_zone]'] option[selected]")&.[]("value"))
      .to eq("America/Costa_Rica")
    expect(response.parsed_body.at_css("meta[name='turbo-cache-control']")&.[]("content")).to eq("no-cache")

    get new_event_plan_booking_path(booking.event_plan)
    expect(response.parsed_body.at_css("meta[name='turbo-cache-control']")&.[]("content")).to eq("no-cache")
  end

  it "rejects stale updates without overwriting private logistics" do
    booking = create(:booking, notes: "Original")
    Bookings::Save.call(booking, attributes: {}, locale: :en)
    rendered_version = booking.lock_version
    booking.update!(notes: "Newer private note")
    sign_in booking.user

    patch booking_path(booking), params: {
      booking: valid_attributes.merge(notes: "Stale overwrite", lock_version: rendered_version)
    }

    expect(response).to redirect_to(event_plan_bookings_path(booking.event_plan))
    expect(flash[:alert]).to eq("The booking changed before your update was saved. Review it and try again.")
    expect(booking.reload.notes).to eq("Newer private note")

    patch booking_path(booking), params: { booking: { notes: "Unversioned overwrite" } }
    expect(response).to have_http_status(:bad_request)
    expect(booking.reload.notes).to eq("Newer private note")
  end

  it "does not disclose or mutate another owner's records" do
    owner = create(:user)
    owned_plan = create(:event_plan, user: owner, relationship_profile: create(:relationship_profile, user: owner))
    foreign_booking = create(:booking)
    sign_in owner

    get event_plan_bookings_path(foreign_booking.event_plan)
    expect(response).to have_http_status(:not_found)

    expect do
      post event_plan_bookings_path(owned_plan), params: {
        booking: valid_attributes.merge(plan_task_id: foreign_booking.plan_task_id)
      }
    end.to change(Booking, :count).by(1)
    expect(owned_plan.bookings.last.plan_task.event_plan).to eq(owned_plan)

    patch booking_path(foreign_booking), params: { booking: valid_attributes.merge(lock_version: foreign_booking.lock_version) }
    expect(response).to have_http_status(:not_found)
  end

  it "keeps terminal-plan bookings readable and removable but not editable" do
    booking = create(:booking)
    Bookings::Save.call(booking, attributes: {}, locale: :en)
    booking.event_plan.complete!
    sign_in booking.user

    get event_plan_bookings_path(booking.event_plan)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Booking details are read-only")
    expect(response.body).not_to include("Add booking", "Edit booking", "Set confirmation reminder")

    expect { delete booking_path(booking) }.to change(Booking, :count).by(-1)
    expect(response).to redirect_to(event_plan_bookings_path(booking.event_plan))
  end

  it "renders localized validation errors and Spanish workflow copy" do
    plan = create(:event_plan)
    sign_in plan.user

    post event_plan_bookings_path(plan), params: { booking: valid_attributes.merge(title: "", provider_name: "") }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Title can&#39;t be blank", "Provider can&#39;t be blank")

    I18n.with_locale(:es) { get event_plan_bookings_path(plan) }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Reservas", "Agregar reserva", "Solo seguimiento manual")
    expect(response.body).not_to include("Translation missing")
  end

  it "shows the booking section inside the event-plan workspace" do
    booking = create(:booking, title: "Dinner reservation")
    Bookings::Save.call(booking, attributes: {}, locale: :en)
    sign_in booking.user

    get event_plan_path(booking.event_plan)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Bookings", "Dinner reservation", "Casa Verde")
    expect(response.body).to include(event_plan_bookings_path(booking.event_plan))
  end

  it "keeps owner booking history navigable after an event plan is archived" do
    booking = create(:booking, title: "Retained private dinner")
    foreign_booking = create(:booking, title: "Another owner's booking")
    booking.event_plan.update!(status: "archived")
    sign_in booking.user

    get event_plans_path
    expect(response).to have_http_status(:ok)
    expect(Capybara.string(response.body)).to have_link("Booking history", href: bookings_path)

    get bookings_path
    expect(response).to have_http_status(:ok)
    history_page = Capybara.string(response.body)
    expect(response.body).to include("Booking history", "Retained private dinner")
    expect(response.body).not_to include("Another owner&#39;s booking")
    expect(history_page).to have_button("Remove booking")
    expect(history_page).not_to have_link(booking.event_plan.title, href: event_plan_path(booking.event_plan))
    expect(response.parsed_body.at_css("meta[name='turbo-cache-control']")&.[]("content")).to eq("no-cache")
    expect(foreign_booking).to be_persisted
  end

  it "paginates account-wide booking history" do
    plan = create(:event_plan)
    create_list(:booking, 21, user: plan.user, event_plan: plan)
    sign_in plan.user

    get bookings_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Page 1 of 2", "Next")
    expect(Capybara.string(response.body)).to have_button("Remove booking", count: 20)
  end
end
