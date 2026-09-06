module DataExports
  class Prepare
    Result = Data.define(:snapshot, :error)

    def self.call(user:, include_sensitive:, **options)
      if include_sensitive
        # Keep verification and protected reads under the same account lock so
        # enrollment, password changes, and factor consumption cannot interleave.
        user.with_lock { prepare(user:, include_sensitive:, **options) }
      else
        prepare(user:, include_sensitive:, **options)
      end
    end

    def self.prepare(user:, relationship_profile:, format:, include_sensitive:, password:, code: nil)
      if relationship_profile && relationship_profile.user_id != user.id
        raise ActiveRecord::RecordNotFound
      end

      if include_sensitive
        verification = PrivacyVault::Verify.call(user:, password:, code:)
        unless verification.in?(%i[password totp recovery])
          return Result.new(snapshot: nil, error: user.vault_mfa_enabled? ? verification : :password_required)
        end
      end

      snapshot = unless format == "ics"
        Snapshot.new(user:, relationship_profile:, include_sensitive:, include_file_contents: format.in?(%w[json csv])).to_h
      end
      Result.new(snapshot:, error: nil)
    end

    private_class_method :prepare
  end
end
