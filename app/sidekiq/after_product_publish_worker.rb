# frozen_string_literal: true

class AfterProductPublishWorker
  include Sidekiq::Job
  sidekiq_options retry: 3, queue: :default

  def perform(product_id)
    product = Link.find(product_id)
    user = product.user

    user.direct_affiliates.alive.apply_to_all_products.find_each do |affiliate|
      unless affiliate.products.include?(product)
        affiliate.products << product
        AffiliateMailer.notify_direct_affiliate_of_new_product(affiliate.id, product.id).deliver_later
      end
    end
  end
end
