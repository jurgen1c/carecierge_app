# Jurgen Clausen's production account. Existing credentials and access state are preserved.
unless User.where("LOWER(email) = ?", "jurgen1c@gmail.com").exists?
  User.create!(email: "jurgen1c@gmail.com") do |user|
    user.password = ENV.fetch("PRODUCTION_SEED_PASSWORD")
    user.skip_confirmation_notification!
  end
end
