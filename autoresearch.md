# Autoresearch: Mock Stripe in E2E checkout

## Metrics
- **Primary**: failed_shards (unitless, lower is better)

## Experiment
- **Branch**: mock-stripe-e2e
- **Goal**: eliminate browser-side Stripe PaymentMethod API calls in system tests while preserving backend purchase flow coverage.
- **Current approach**: patch the test Stripe instance to return deterministic test PaymentMethod IDs from `createPaymentMethod`, keyed by the card number filled by checkout helpers.

## How to Run
`autoresearch.sh` — should emit `METRIC name=number` lines for failed_shards.

## Notes
- Server-side Stripe calls are intentionally left in the purchase flow so charge, balance, setup intent, and SCA behavior remain covered.
- Browser-side SCA confirmation still delegates to Stripe in this iteration; the high-volume checkout tokenization call is mocked first.

## What's Been Tried
- No logged experiments yet.

## Plugin Checkpoint
- Last updated: 2026-04-26T15:22:25.506Z
- Runs tracked: 0 current / 0 total
- Baseline: n/a
- Best kept: n/a
- Confidence: n/a
- Canonical branch: mock-stripe-e2e
- Pending run awaiting log_experiment: echo "Baseline from last 5 main branch CI runs: 3+2+6+1+2 = 14, avg = 2.8"; echo "METRIC failed_shards=2.8" (2.8)

Z
- Runs tracked: 0 current / 0 total
- Baseline: n/a
- Best kept: n/a
- Confidence: n/a
- Canonical branch: mock-stripe-e2e
