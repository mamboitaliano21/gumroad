# frozen_string_literal: true

require "spec_helper"

describe Onetime::MigrateBulgariaBgnBalancesToEur do
  let(:bg_eur_account) do
    create(:merchant_account, country: "BG", currency: "eur")
  end

  let(:bg_bgn_account) do
    create(:merchant_account, country: "BG", currency: "bgn")
  end

  let(:us_account) do
    create(:merchant_account, country: "US", currency: "usd")
  end

  describe ".process" do
    context "in dry-run mode (default)" do
      it "does not change merchant accounts or balances" do
        bgn_account = bg_bgn_account
        balance = create(:balance, merchant_account: bg_eur_account, holding_currency: "bgn", holding_amount_cents: 19_558)

        described_class.process

        expect(bgn_account.reload.currency).to eq("bgn")
        expect(balance.reload.holding_currency).to eq("bgn")
        expect(balance.holding_amount_cents).to eq(19_558)
      end
    end

    context "in write mode" do
      it "flips currency from bgn to eur on Bulgarian merchant accounts" do
        bgn_account = bg_bgn_account
        eur_account = bg_eur_account

        described_class.process(dry_run: false)

        expect(bgn_account.reload.currency).to eq("eur")
        expect(eur_account.reload.currency).to eq("eur")
      end

      it "leaves merchant accounts in other countries untouched" do
        non_bg_with_bgn = create(:merchant_account, country: "DE", currency: "bgn")

        described_class.process(dry_run: false)

        expect(non_bg_with_bgn.reload.currency).to eq("bgn")
      end

      it "converts unpaid BGN balances on Bulgarian merchant accounts to EUR at 1.95583" do
        balance = create(:balance, merchant_account: bg_eur_account, holding_currency: "bgn", holding_amount_cents: 19_558)

        described_class.process(dry_run: false)

        expect(balance.reload.holding_currency).to eq("eur")
        expect(balance.holding_amount_cents).to eq(10_000)
      end

      it "rounds to the nearest cent when converting" do
        balance = create(:balance, merchant_account: bg_eur_account, holding_currency: "bgn", holding_amount_cents: 100)

        described_class.process(dry_run: false)

        expect(balance.reload.holding_amount_cents).to eq(51)
      end

      it "leaves the issued currency and amount_cents untouched" do
        balance = create(:balance,
                         merchant_account: bg_eur_account,
                         currency: "usd",
                         amount_cents: 10_000,
                         holding_currency: "bgn",
                         holding_amount_cents: 19_558)

        described_class.process(dry_run: false)

        balance.reload
        expect(balance.currency).to eq("usd")
        expect(balance.amount_cents).to eq(10_000)
      end

      it "ignores BGN balances on non-Bulgarian merchant accounts" do
        balance = create(:balance, merchant_account: us_account, holding_currency: "bgn", holding_amount_cents: 19_558)

        described_class.process(dry_run: false)

        expect(balance.reload.holding_currency).to eq("bgn")
        expect(balance.holding_amount_cents).to eq(19_558)
      end

      it "ignores non-BGN balances on Bulgarian merchant accounts" do
        balance = create(:balance, merchant_account: bg_eur_account, holding_currency: "eur", holding_amount_cents: 10_000)

        described_class.process(dry_run: false)

        expect(balance.reload.holding_currency).to eq("eur")
        expect(balance.holding_amount_cents).to eq(10_000)
      end

      it "ignores already-paid balances" do
        balance = create(:balance,
                         merchant_account: bg_eur_account,
                         holding_currency: "bgn",
                         holding_amount_cents: 19_558,
                         state: "paid")

        described_class.process(dry_run: false)

        balance.reload
        expect(balance.holding_currency).to eq("bgn")
        expect(balance.holding_amount_cents).to eq(19_558)
      end

      it "ignores processing balances" do
        balance = create(:balance,
                         merchant_account: bg_eur_account,
                         holding_currency: "bgn",
                         holding_amount_cents: 19_558,
                         state: "processing")

        described_class.process(dry_run: false)

        balance.reload
        expect(balance.holding_currency).to eq("bgn")
        expect(balance.holding_amount_cents).to eq(19_558)
      end

      it "prints each merchant_account and balance with previous and new values" do
        account = bg_bgn_account
        balance = create(:balance, merchant_account: bg_eur_account, holding_currency: "bgn", holding_amount_cents: 19_558)

        expect { described_class.process(dry_run: false) }.to output(
          a_string_including(
            "merchant_account id=#{account.id} currency=bgn -> eur",
            "balance id=#{balance.id} user_id=#{balance.user_id} merchant_account_id=#{balance.merchant_account_id} " \
            "holding_currency=bgn -> eur, holding_amount_cents=19558 -> 10000"
          )
        ).to_stdout
      end

      it "is idempotent — re-running produces no further changes" do
        balance = create(:balance, merchant_account: bg_eur_account, holding_currency: "bgn", holding_amount_cents: 19_558)

        described_class.process(dry_run: false)
        first_pass_cents = balance.reload.holding_amount_cents
        described_class.process(dry_run: false)

        expect(balance.reload.holding_currency).to eq("eur")
        expect(balance.holding_amount_cents).to eq(first_pass_cents)
      end
    end
  end
end
