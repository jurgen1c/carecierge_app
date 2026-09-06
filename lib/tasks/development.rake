namespace :development do
  desc "Seed isolated synthetic journeys (development only; REFERENCE_DATE=YYYY-MM-DD)"
  task seed: :environment do
    require Rails.root.join("lib/development_seeds/world")
    DevelopmentSeeds::World.new(reference_date: ENV.fetch("REFERENCE_DATE", "2026-09-06")).seed!
    puts "Synthetic journeys ready. See docs/development/journeys.md for accounts and routes."
  end

  desc "Remove only reserved synthetic journey records (development only)"
  task reset_seeds: :environment do
    require Rails.root.join("lib/development_seeds/world")
    DevelopmentSeeds::World.new.reset!
    puts "Synthetic journey records removed."
  end
end
