module RemindersHelper
  def reminder_time_zone_options
    TZInfo::Timezone.all_identifiers.map do |identifier|
      zone = TZInfo::Timezone.get(identifier)
      offset = zone.current_period.utc_total_offset
      [ time_zone_label(identifier, offset), identifier, offset ]
    end.sort_by { |(_label, identifier, offset)| [ offset, identifier ] }
      .map { |label, identifier, _offset| [ label, identifier ] }
  end

  private

  def time_zone_label(identifier, offset)
    sign = offset.negative? ? "-" : "+"
    hours, remainder = offset.abs.divmod(1.hour)
    minutes = remainder / 1.minute
    format("(UTC%s%02d:%02d) %s", sign, hours, minutes, identifier.tr("_", " "))
  end
end
