module SharedSpaces
  class ChangeItem
    def self.call(space:, actor:, item: nil, attributes: {}, action: :save, revision: nil)
      actor.with_lock("FOR NO KEY UPDATE") do
        change_under_account_lock(space:, actor:, item:, attributes:, action:, revision:)
      end
    end

    def self.change_under_account_lock(space:, actor:, item:, attributes:, action:, revision:)
      space.with_lock do
        raise ActiveRecord::RecordNotFound unless space.active? && space.participant?(actor)
        item = item ? space.shared_items.lock.find(item.id) : space.shared_items.build(creator: actor)
        policy = SharedItemPolicy.new(actor, item)
        case action
        when :save
          raise Pundit::NotAuthorizedError unless item.new_record? ? policy.create? : policy.update?
          require_revision!(item, attributes[:lock_version]) if item.persisted?
          values = attributes.except(:lock_version).dup
          values.delete(:editing) unless item.creator_id == actor.id
          values.delete(:kind) if item.persisted?
          if values[:parent_id].present?
            values[:parent_id] = space.shared_items.where(kind: "plan").find(values[:parent_id]).id
          end
          schedule = values.delete(:scheduled_local)
          item.assign_attributes(values)
          item.scheduled_local = schedule unless schedule.nil?
          item.save!
        when :destroy
          raise Pundit::NotAuthorizedError unless policy.destroy?
          item.destroy!
        when :complete
          raise Pundit::NotAuthorizedError unless policy.update?
          require_revision!(item, revision)
          item.update!(completed_at: item.completed? ? nil : Time.current)
        when :claim
          raise Pundit::NotAuthorizedError unless item.kind == "task" && !item.completed? && policy.show?
          raise Pundit::NotAuthorizedError if item.assignee_id.present? && item.assignee_id != actor.id
          require_revision!(item, revision)
          item.update!(assignee: item.assignee_id == actor.id ? nil : actor)
        when :subscribe
          item.shared_reminder_subscriptions.find_or_create_by!(user: actor)
        when :unsubscribe
          item.shared_reminder_subscriptions.where(user: actor).destroy_all
        end
        item
      end
    end

    def self.require_revision!(item, revision)
      raise ActiveRecord::StaleObjectError.new(item, "update") unless revision.to_s.match?(/\A\d+\z/) && item.lock_version == revision.to_i
    end
    private_class_method :require_revision!, :change_under_account_lock
  end
end
