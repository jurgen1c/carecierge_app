module Bookings
  class Destroy
    def self.call(booking)
      Booking.transaction do
        booking.user.with_lock("FOR NO KEY UPDATE") do
          booking.event_plan.relationship_profile.with_lock do
            booking.event_plan.with_lock do
              booking.lock!
              task = booking.plan_task
              booking.destroy!
              task&.destroy!
              booking.event_plan.increment!(:generation_version) if task
            end
          end
        end
      end
    end
  end
end
