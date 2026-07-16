module Digests
  Item = Data.define(:kind, :title, :relationship_profile, :record, :due_at, :overdue) do
    def relationship_name = relationship_profile.display_name
  end

  Digest = Data.define(:mode, :as_of, :items) do
    def empty? = items.empty?
    def start_item = items.first
    def remaining_items = items.drop(1)
  end

  class Compose
    MAX_ITEMS = 8
    KIND_ORDER = { commitment: 0, check_in: 1, upcoming_date: 2, planning_prompt: 3 }.freeze

    def self.call(user:, as_of:, mode:)
      new(user:, as_of:, mode:).call
    end

    def initialize(user:, as_of:, mode:)
      @user = user
      supplied_zone = as_of.time_zone if as_of.respond_to?(:time_zone)
      @as_of = supplied_zone ? as_of.in_time_zone(supplied_zone) : as_of.in_time_zone
      @mode = mode
    end

    def call
      items = eligible_profiles.flat_map { |profile| items_for(profile) }
      items.sort_by! { |item| [ item.overdue ? 0 : 1, item.due_at, KIND_ORDER.fetch(item.kind), item.title.downcase ] }

      Digest.new(mode:, as_of:, items: items.first(MAX_ITEMS))
    end

    private

    attr_reader :user, :as_of, :mode

    def eligible_profiles
      muted_ids = user.notification_preference&.relationship_notification_preferences&.pluck(:relationship_profile_id) || []
      user.relationship_profiles.active
        .where.not(id: muted_ids)
        .includes(:commitments, :important_dates, :contact_cadence, :interactions)
    end

    def items_for(profile)
      commitment_items(profile) + important_date_items(profile) + check_in_items(profile)
    end

    def commitment_items(profile)
      profile.commitments.filter_map do |commitment|
        next unless commitment.open? && commitment.due_on.present? && commitment.due_on <= horizon_date

        Item.new(
          kind: :commitment,
          title: commitment.title,
          relationship_profile: profile,
          record: commitment,
          due_at: commitment.due_on.beginning_of_day,
          overdue: commitment.due_on < as_of.to_date
        )
      end
    end

    def important_date_items(profile)
      profile.important_dates.filter_map do |important_date|
        occurrence = important_date.next_occurrence_on(as_of: as_of.to_date)
        next unless occurrence

        kind = occurrence <= horizon_date ? :upcoming_date : :planning_prompt
        next if kind == :planning_prompt && !important_date.planning_opportunity?(as_of: as_of.to_date)

        Item.new(
          kind:,
          title: important_date.display_title,
          relationship_profile: profile,
          record: important_date,
          due_at: occurrence.beginning_of_day,
          overdue: false
        )
      end
    end

    def check_in_items(profile)
      cadence = profile.contact_cadence
      return [] unless cadence

      last_interaction_at = profile.interactions.map(&:occurred_at).max
      due_at = (last_interaction_at || cadence.created_at) + cadence.interval_days.days
      return [] if due_at > horizon_end

      [ Item.new(
        kind: :check_in,
        title: profile.display_name,
        relationship_profile: profile,
        record: cadence,
        due_at:,
        overdue: due_at < as_of
      ) ]
    end

    def horizon_date
      @horizon_date ||= as_of.to_date + (mode == "weekly" ? 7.days : 0.days)
    end

    def horizon_end
      zone = as_of.respond_to?(:time_zone) && as_of.time_zone ? as_of.time_zone : Time.zone
      zone.local(horizon_date.year, horizon_date.month, horizon_date.day).end_of_day
    end
  end
end
