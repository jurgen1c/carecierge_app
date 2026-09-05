module GiftPurchasePlans
  class Save
    def self.call(gift:, attributes:, expected_version:)
      gift.relationship_profile.user.with_lock do
        gift.relationship_profile.with_lock do
          raise ActiveRecord::RecordNotFound unless gift.relationship_profile.kept?

          gift.lock!
          plan = gift.purchase_plan || gift.build_purchase_plan
          actual_version = plan.persisted? ? plan.lock_version.to_s : "new"
          raise ActiveRecord::StaleObjectError.new(plan, "update") unless actual_version == expected_version

          plan.update!(attributes)
          plan
        end
      end
    end
  end
end
