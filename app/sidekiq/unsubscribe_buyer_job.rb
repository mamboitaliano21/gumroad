# frozen_string_literal: true

class UnsubscribeBuyerJob
  include Sidekiq::Job
  sidekiq_options retry: 5, queue: :default

  MAX_LOCK_WAIT_ATTEMPTS = 5

  def perform(purchase_id, lock_wait_attempt = 1)
    Purchase.find(purchase_id).unsubscribe_buyer
  rescue ActiveRecord::LockWaitTimeout => e
    if lock_wait_attempt >= MAX_LOCK_WAIT_ATTEMPTS
      ErrorNotifier.notify(e, purchase_id:, lock_wait_attempt:)
    else
      self.class.perform_in((lock_wait_attempt * 30).seconds, purchase_id, lock_wait_attempt + 1)
    end
  end
end
