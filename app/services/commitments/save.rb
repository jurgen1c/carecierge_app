module Commitments
  class Save
    EVENTS = {
      complete: :complete!,
      cancel: :cancel!,
      reopen: :reopen!
    }.freeze

    def self.call(commitment, attributes: nil, event: nil)
      new(commitment, attributes:, event:).call
    end

    def initialize(commitment, attributes:, event:)
      @commitment = commitment
      @attributes = attributes
      @event = event
    end

    def call
      validate_operation!

      Commitment.transaction do
        persist_commitment!
        sync_timeline_entry!
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    private

    attr_reader :commitment, :attributes, :event

    def validate_operation!
      raise ArgumentError, "provide exactly one of attributes or event" if attributes.nil? == event.nil?
      raise ArgumentError, "unsupported commitment event: #{event}" if event && !EVENTS.key?(event)
    end

    def persist_commitment!
      if event
        commitment.public_send(EVENTS.fetch(event))
      else
        commitment.assign_attributes(attributes)
        commitment.save!
      end
    end

    def sync_timeline_entry!
      timeline_entry = commitment.timeline_entry || commitment.relationship_profile.timeline_entries.build(source_record: commitment)
      timeline_entry.assign_attributes(
        entry_type: "promise",
        origin: "system",
        title: commitment.title,
        body: commitment.notes,
        occurred_at: timeline_entry.occurred_at || commitment.created_at
      )
      timeline_entry.save!
    end
  end
end
