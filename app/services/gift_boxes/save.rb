module GiftBoxes
  class Save
    def self.call(box:, attributes:, expected_version: nil)
      profile = box.relationship_profile
      profile.user.with_lock("FOR NO KEY UPDATE") do
        profile.with_lock do
          raise ActiveRecord::RecordNotFound unless profile.kept?

          if box.persisted?
            box.lock!
            raise ActiveRecord::StaleObjectError.new(box, "update") unless box.lock_version.to_s == expected_version
          end
          version = box.lock_version
          box.assign_attributes(attributes)
          box.save!
          # Nested item edits participate in the same optimistic version as the
          # box form, including edits that happen within one timestamp tick.
          box.touch if expected_version && box.lock_version == version
          box
        end
      end
    end
  end
end
