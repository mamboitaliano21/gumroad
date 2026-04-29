# frozen_string_literal: true

require "spec_helper"

describe AfterProductPublishJob do
  before do
    @user = create(:user)
    @product = create(:product, user: @user)
  end

  describe "#perform" do
    it "associates universal affiliates with the product and notifies them" do
      direct_affiliate = create(:direct_affiliate, seller: @user, apply_to_all_products: true)

      expect do
        described_class.new.perform(@product.id)
      end.to have_enqueued_mail(AffiliateMailer, :notify_direct_affiliate_of_new_product).with(direct_affiliate.id, @product.id)

      expect(@product.reload.direct_affiliates).to match_array [direct_affiliate]
      expect(direct_affiliate.reload.products).to match_array [@product]
    end

    context "when affiliate is already associated with the product" do
      it "does not add or notify them" do
        direct_affiliate = create(:direct_affiliate, seller: @user, apply_to_all_products: true, products: [@product])

        expect do
          described_class.new.perform(@product.id)
        end.to_not have_enqueued_mail(AffiliateMailer, :notify_direct_affiliate_of_new_product).with(direct_affiliate.id, @product.id)

        expect(@product.reload.direct_affiliates).to match_array [direct_affiliate]
        expect(direct_affiliate.reload.products).to match_array [@product]
      end
    end

    context "when affiliate has been removed" do
      it "does not add or notify them" do
        direct_affiliate = create(:direct_affiliate, seller: @user, apply_to_all_products: true)
        direct_affiliate.mark_deleted!

        expect do
          described_class.new.perform(@product.id)
        end.to_not have_enqueued_mail(AffiliateMailer, :notify_direct_affiliate_of_new_product).with(direct_affiliate.id, @product.id)

        expect(@product.reload.direct_affiliates).to be_empty
        expect(direct_affiliate.reload.products).to be_empty
      end
    end
  end
end
