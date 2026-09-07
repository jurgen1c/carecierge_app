require Rails.root.join("lib/development_seeds/world")
DevelopmentSeeds::World.new(reference_date: ENV.fetch("REFERENCE_DATE", "2026-09-06")).seed!
puts "Synthetic journeys ready. See docs/development/journeys.md for accounts and routes."
