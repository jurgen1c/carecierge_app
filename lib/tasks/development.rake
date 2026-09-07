namespace :development do
  desc "Remove only reserved synthetic journey records (development only)"
  task reset_seeds: :environment do
    require Rails.root.join("lib/development_seeds/world")
    DevelopmentSeeds::World.new.reset!
    puts "Synthetic journey records removed."
  end
end
