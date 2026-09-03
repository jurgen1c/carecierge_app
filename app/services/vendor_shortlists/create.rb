module VendorShortlists
  class Create
    def self.call(user:, attributes:, vendors:) = new(user:, attributes:, vendors:).call

    def initialize(user:, attributes:, vendors:)
      @user = user
      @attributes = attributes
      @vendor_ids = vendors.map(&:id).uniq
    end

    def call
      shortlist = user.vendor_shortlists.new(attributes)
      validate_context_presence!(shortlist)

      with_context_locks(shortlist) do
        validate_option_count!(shortlist)
        vendors = resolve_vendors!
        shortlist.save!
        vendors.each { |vendor| shortlist.vendor_options.create!(vendor:) }
      end

      shortlist
    rescue ActiveRecord::RecordInvalid => error
      raise if error.record == shortlist

      shortlist.errors.add(:vendor_options, error.record.errors.full_messages.to_sentence)
      raise ActiveRecord::RecordInvalid, shortlist
    end

    private

    attr_reader :user, :attributes, :vendor_ids

    def validate_context_presence!(shortlist)
      return if shortlist.relationship_profile_id

      shortlist.validate
      return if shortlist.relationship_profile_id

      raise ActiveRecord::RecordInvalid, shortlist
    end

    def with_context_locks(shortlist)
      user.with_lock("FOR NO KEY UPDATE") do
        relationship_profile = user.relationship_profiles.find(shortlist.relationship_profile_id)
        relationship_profile.with_lock do
          raise ActiveRecord::RecordNotFound unless relationship_profile.kept?

          shortlist.relationship_profile = relationship_profile
          lock_event_plan_and_yield(shortlist) { yield }
        end
      end
    end

    def lock_event_plan_and_yield(shortlist)
      return yield unless shortlist.event_plan_id

      event_plan = user.event_plans.find(shortlist.event_plan_id)
      event_plan.with_lock do
        raise ActiveRecord::RecordNotFound unless event_plan.active?
        raise ActiveRecord::RecordNotFound unless event_plan.relationship_profile_id == shortlist.relationship_profile_id

        shortlist.event_plan = event_plan
        yield
      end
    end

    def validate_option_count!(shortlist)
      return if vendor_ids.length <= VendorShortlist::MAX_OPTIONS

      shortlist.errors.add(:vendor_options, :too_many, count: VendorShortlist::MAX_OPTIONS)
      raise ActiveRecord::RecordInvalid, shortlist
    end

    def resolve_vendors!
      vendors_by_id = user.vendors.where(id: vendor_ids).index_by(&:id)
      raise ActiveRecord::RecordNotFound unless vendors_by_id.length == vendor_ids.length

      vendor_ids.map { |id| vendors_by_id.fetch(id) }
    end
  end
end
