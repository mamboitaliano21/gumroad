# frozen_string_literal: true

require "spec_helper"

describe UnsubscribeBuyerJob do
  describe "sidekiq options" do
    it "retries 5 times on the default queue" do
      expect(described_class.sidekiq_options["retry"]).to eq(5)
      expect(described_class.sidekiq_options["queue"]).to eq(:default)
    end
  end

  describe "#perform" do
    it "calls unsubscribe_buyer on the purchase" do
      purchase = create(:purchase, can_contact: true)

      described_class.new.perform(purchase.id)

      expect(purchase.reload.can_contact).to eq(false)
    end

    it "unsubscribes all of the buyer's purchases from the same seller" do
      seller = create(:user)
      buyer_email = "buyer@example.com"
      purchase_1 = create(:purchase, link: create(:product, user: seller), seller:, email: buyer_email, can_contact: true)
      purchase_2 = create(:purchase, link: create(:product, user: seller), seller:, email: buyer_email, can_contact: true)
      other_seller_purchase = create(:purchase, email: buyer_email, can_contact: true)

      described_class.new.perform(purchase_1.id)

      expect(purchase_1.reload.can_contact).to eq(false)
      expect(purchase_2.reload.can_contact).to eq(false)
      expect(other_seller_purchase.reload.can_contact).to eq(true)
    end

    it "raises ActiveRecord::RecordNotFound when the purchase is missing" do
      expect { described_class.new.perform(0) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context "when ActiveRecord::LockWaitTimeout is raised" do
      let(:purchase) { create(:purchase, can_contact: true) }

      before do
        allow(Purchase).to receive(:find).with(purchase.id).and_return(purchase)
        allow(purchase).to receive(:unsubscribe_buyer).and_raise(ActiveRecord::LockWaitTimeout)
      end

      it "re-enqueues with incremented attempt counter when not on the last attempt" do
        expect do
          described_class.new.perform(purchase.id, 1)
        end.to change { described_class.jobs.size }.by(1)

        expect(described_class.jobs.last["args"]).to eq([purchase.id, 2])
      end

      it "notifies Sentry via ErrorNotifier on the last attempt without re-enqueuing" do
        expect(ErrorNotifier).to receive(:notify).with(
          instance_of(ActiveRecord::LockWaitTimeout),
          purchase_id: purchase.id,
          lock_wait_attempt: UnsubscribeBuyerJob::MAX_LOCK_WAIT_ATTEMPTS,
        )

        expect do
          described_class.new.perform(purchase.id, UnsubscribeBuyerJob::MAX_LOCK_WAIT_ATTEMPTS)
        end.not_to change { described_class.jobs.size }
      end
    end
  end
end
