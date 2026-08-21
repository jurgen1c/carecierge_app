class OwnerLocalCalendar
  def self.date_for(user:, at: Time.current)
    return at if at.is_a?(Date) && !at.is_a?(DateTime)

    at.in_time_zone(time_zone_for(user:)).to_date
  end

  def self.time_zone_for(user:)
    time_zone_name = user.notification_preference&.time_zone.presence
    (ActiveSupport::TimeZone[time_zone_name] if time_zone_name) || Time.zone
  end
end
