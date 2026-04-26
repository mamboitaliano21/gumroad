# Autoresearch: Mock Stripe in E2E checkout

## Metrics
- **Primary**: failed_shards (unitless, lower is better)
- **Direction**: lower is better
- **Baseline**: ~2.7 failed shards per CI run

## Experiment
- **Branch**: mock-stripe-e2e
- **Goal**: eliminate browser-side Stripe PaymentMethod API calls in system tests while preserving backend purchase flow coverage.
- **Current approach**: patch the test Stripe instance to return deterministic test PaymentMethod IDs from `createPaymentMethod`, keyed by the card number filled by checkout helpers.

## How to Run
- `./autoresearch.sh` pushes the current SHA to three CI branches, waits for CI, and emits `METRIC failed_shards=<average>`.

## Notes
- Server-side Stripe calls are intentionally left in the purchase flow so charge, balance, setup intent, and SCA behavior remain covered.
- Browser-side SCA confirmation still delegates to Stripe in this iteration; the high-volume checkout tokenization call is mocked first.
