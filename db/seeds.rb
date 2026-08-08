# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

RelationshipTemplate.install_defaults!

FeatureFlag.find_or_create_by!(key: "ai_memory_extraction") do |flag|
  flag.name = "AI memory extraction"
  flag.description = "Allows opted-in conversation recaps to produce source-backed memory proposals for owner review."
  flag.enabled = false
end
