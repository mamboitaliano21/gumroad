# frozen_string_literal: true

# Migrates leftover BGN-denominated state on Bulgarian Stripe Connect accounts
# to EUR following Bulgaria's euro adoption on 2026-01-01.
#
# Stripe converts pegged BGN balances to EUR at the legal fixed rate of
# 1.95583 BGN = 1 EUR. This script brings our records in sync with what
# Stripe holds, so `StripePayoutProcessor.is_balance_payable` (which compares
# `Balance#holding_currency` to `MerchantAccount#currency`) stops rejecting
# them.
#
# The script:
#   1. Flips `currency` from "bgn" to "eur" on BG `merchant_accounts` (the
#      unchecked follow-up from PR #2437).
#   2. Converts unpaid `balances` whose `holding_currency` is "bgn" and whose
#      merchant account is Bulgarian: divides `holding_amount_cents` by the
#      fixed rate and sets `holding_currency` to "eur".
#
# Already-paid and processing balances are left untouched: they are historical
# records of the actual settled currency at the time, and processing balances
# are mid-payout.
#
# Usage:
#   Onetime::MigrateBulgariaBgnBalancesToEur.process            # dry-run
#   Onetime::MigrateBulgariaBgnBalancesToEur.process(dry_run: false)
module Onetime
  class MigrateBulgariaBgnBalancesToEur
    BGN = "bgn"
    BGN_PER_EUR = BigDecimal("1.95583")
    BATCH_SIZE = 500

    def self.process(dry_run: true)
      new(dry_run:).process
    end

    def initialize(dry_run:)
      @dry_run = dry_run
    end

    def process
      puts "Running in #{@dry_run ? 'DRY-RUN' : 'WRITE'} mode"
      update_merchant_accounts
      update_unpaid_balances
    end

    private
      def bg_alpha2
        Compliance::Countries::BGR.alpha2
      end

      def update_merchant_accounts
        scope = MerchantAccount.where(country: bg_alpha2, currency: BGN)
        puts "merchant_accounts to update: #{scope.count}"

        scope.find_in_batches(batch_size: BATCH_SIZE) do |batch|
          ReplicaLagWatcher.watch
          ids = batch.map(&:id)
          puts "merchant_accounts batch: #{ids.first}..#{ids.last}"
          MerchantAccount.where(id: ids).update_all(currency: Currency::EUR) unless @dry_run
        end
      end

      def update_unpaid_balances
        scope = Balance
          .joins(:merchant_account)
          .where(state: "unpaid", holding_currency: BGN)
          .where(merchant_accounts: { country: bg_alpha2 })

        puts "unpaid balances to convert: #{scope.count}"

        scope.find_in_batches(batch_size: BATCH_SIZE) do |batch|
          ReplicaLagWatcher.watch
          puts "balances batch: #{batch.first.id}..#{batch.last.id}"

          next if @dry_run

          batch.each do |balance|
            eur_cents = (BigDecimal(balance.holding_amount_cents) / BGN_PER_EUR).round
            balance.update_columns(
              holding_currency: Currency::EUR,
              holding_amount_cents: eur_cents,
            )
          end
        end
      end
  end
end
