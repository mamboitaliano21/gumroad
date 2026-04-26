# frozen_string_literal: true

class TestSupport::StripeController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create_payment_method
    token = params[:token] || "tok_visa"
    payment_method = Stripe::PaymentMethod.create(type: "card", card: { token: token })
    render json: {
      id: payment_method.id,
      card: {
        brand: payment_method.card.brand,
        last4: payment_method.card.last4,
        exp_month: payment_method.card.exp_month,
        exp_year: payment_method.card.exp_year,
        country: payment_method.card.country,
        fingerprint: payment_method.card.fingerprint,
        funding: payment_method.card.funding
      }
    }
  rescue Stripe::StripeError => e
    render json: { error: { type: e.class.name, message: e.message } }, status: :unprocessable_entity
  end
end
