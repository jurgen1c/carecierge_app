# Jurgen Clausen's production account. Existing credentials and access state are preserved.
User.find_or_create_by!(email: "jurgen1c@gmail.com") do |user|
  user.password = ENV.fetch("PRODUCTION_SEED_PASSWORD")
  user.skip_confirmation_notification!
end
