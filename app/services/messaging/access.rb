module Messaging
  class Access
    def self.call(user:)
      user.with_lock("FOR NO KEY UPDATE") do
        Permission.check!(user:)
        connection = MessagingConnection.lock.find_by!(user_id: user.id)
        raise Error.new(code: "authorization_required") unless connection.status == "connected"
        yield connection
      end
    end
  end
end
