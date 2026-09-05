module Contacts
  class Refresh
    def self.call(user:, more: false)
      error = nil
      user.with_lock("FOR NO KEY UPDATE") do
        connection = ContactsConnection.lock.find_by!(user_id: user.id)
        raise Error.new(code: "disconnected") unless connection.status == "connected"
        Permission.check!(user:)
        raise Error.new(code: "no_more") if more && connection.next_page_token.blank?
        begin
          page = Google.new(connection:).page(page_token: more ? connection.next_page_token : nil)
          page.fetch(:contacts).each do |data|
            external_id = data.fetch("external_id")
            key = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("contacts-provider-key"), external_id)
            contact = connection.imported_contacts.find_or_initialize_by(provider_key: key)
            contact.assign_attributes(external_id:, data: data.except("external_id"))
            contact.save! if contact.changed?
          end
          connection.update!(next_page_token: page[:next_page_token], last_refreshed_at: Time.current)
          AuditEvent.record!(user:, actor: user, action: "contacts.refresh.completed", target: user, metadata: { count: page[:contacts].size, result: "success" })
        rescue Error => failure
          error = failure
          connection.update!(status: "authorization_required") if failure.code.in?(%w[authorization_required invalid_grant])
        end
      end
      raise error if error
    end
  end
end
