class SharedItemComponent < ApplicationViewComponent
  option :item
  option :user

  style do
    base { %w[border-b border-private-line py-6] }
  end
  style :button do
    base { %w[inline-flex min-h-11 items-center justify-center rounded-lg border border-private-line px-3 py-2 text-sm font-semibold text-ink hover:bg-surface focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary] }
  end

  def space = item.shared_relationship_space
  def policy = SharedItemPolicy.new(user, item)
  def subscribed? = item.shared_reminder_subscriptions.any? { |subscription| subscription.user_id == user.id && subscription.enabled? }
end
