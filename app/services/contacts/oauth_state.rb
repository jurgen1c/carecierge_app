module Contacts
  class OauthState
    SESSION_KEY = :contacts_oauth_nonce
    MAX_AGE = 10.minutes

    def self.issue(user:, session:)
      nonce = SecureRandom.hex(32)
      session[SESSION_KEY] = nonce
      verifier.generate(
        { user_id: user.id, nonce:, connection_generation: user.contacts_connection_generation },
        expires_in: MAX_AGE
      )
    end

    def self.verify(state:, user:, session:)
      expected_nonce = session.delete(SESSION_KEY).to_s
      return false if expected_nonce.blank?

      payload = verifier.verify(state.to_s).with_indifferent_access
      return false unless payload[:user_id].to_s == user.id.to_s
      return false unless ActiveSupport::SecurityUtils.secure_compare(payload[:nonce].to_s, expected_nonce)

      Integer(payload[:connection_generation], exception: false) || false
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      false
    end

    def self.verifier
      Rails.application.message_verifier("contacts-connection-oauth-state")
    end
    private_class_method :verifier
  end
end
