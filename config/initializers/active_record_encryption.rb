encryption_credentials = Rails.application.credentials.active_record_encryption || {}
root_secret = Rails.application.secret_key_base
key_generator = ActiveSupport::KeyGenerator.new(root_secret, iterations: 1_000)

Rails.application.config.active_record.encryption.primary_key =
  ENV["CARECIERGE_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].presence ||
  encryption_credentials[:primary_key].presence ||
  key_generator.generate_key("carecierge-active-record-encryption-primary", 32)
Rails.application.config.active_record.encryption.deterministic_key =
  ENV["CARECIERGE_ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"].presence ||
  encryption_credentials[:deterministic_key].presence ||
  key_generator.generate_key("carecierge-active-record-encryption-deterministic", 32)
Rails.application.config.active_record.encryption.key_derivation_salt =
  ENV["CARECIERGE_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"].presence ||
  encryption_credentials[:key_derivation_salt].presence ||
  key_generator.generate_key("carecierge-active-record-encryption-salt", 32)
