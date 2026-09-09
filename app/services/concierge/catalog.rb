module Concierge
  class Catalog
    def self.all
      [ Operations::People, Operations::Memories, Operations::Recaps, Operations::Moods,
        Operations::Interactions, Operations::Timeline, Operations::Commitments, Operations::Desires,
        Operations::Dates, Operations::Preferences, Operations::Notes, Operations::Cadence,
        Operations::Plans, Operations::Tasks, Operations::Reminders, Operations::Proposals, Operations::Priorities,
        Operations::Drafts, Operations::Briefings, Operations::Backups, Operations::Touches,
        Operations::Vendors, Operations::Shortlists, Operations::VendorOptions, Operations::Quotes, Operations::Bookings,
        Operations::Gifts, Operations::GiftIdeas, Operations::GiftPurchases, Operations::GiftBoxes, Operations::Work,
        Operations::Approvals, Operations::PlanIdeas, Operations::Ideas ].flat_map(&:definitions)
    end

    def self.fetch(name)
      all.find { |operation| operation.name == name } || raise(InvalidArguments)
    end

    def self.tools(turn:, token:, names: nil, operation_names: nil)
      operations = all
      operations = operations.select { |operation| names.include?(operation.name.split(".").first) } if names
      operations = operations.select { |operation| operation_names.include?(operation.name) } if operation_names
      operations.map { |operation| Tool.new(operation:, turn:, token:) }
    end
  end
end
