# Autoresearch: Mock Stripe in E2E checkout

## Metrics
- **Primary**: failed_shards (unitless, lower is better)
- **Direction**: lower is better
- **Baseline**: 2.8 failed shards per CI run

## Experiment
- **Branch**: mock-stripe-e2e
- **Goal**: eliminate browser-side Stripe PaymentMethod API calls in system tests while preserving backend purchase flow coverage.
- **Current approach**: patch the test Stripe instance to return deterministic test PaymentMethod IDs from `createPaymentMethod`, keyed by the card number filled by checkout helpers.

## How to Run
- `./autoresearch.sh` pushes the current SHA to three fresh timestamped CI branches, waits for CI, and emits `METRIC failed_shards=<average>`.

## What's Been Tried
- #1 baseline keep 2.8 cdcb64f — Baseline from recent main CI runs; failures primarily Stripe rate-limit errors.
- #2 reject 30.0 cdcb64f — CDP full Stripe.js mock plus server-side test endpoint regressed badly; likely moved tokenization traffic into Rails/Stripe instead of eliminating it.
- #3 inconclusive 4.5 15d4514 — Tokenization-only Stripe.js mock produced no failed-log signatures for Stripe rate limits or “temporary problem” errors, but the all-shard metric regressed due unrelated flaky failures (Elasticsearch ordering, embed prefill/discount status, product variant updater, and membership UI assertions). Rerun for noise.

## Notes
- Server-side Stripe calls are intentionally left in the purchase flow so charge, balance, setup intent, and SCA behavior remain covered.
- Browser-side SCA confirmation still delegates to Stripe in this iteration; the high-volume checkout tokenization call is mocked first.
- `autoresearch.sh` uses fresh CI branch names each loop so repeated runs at the same SHA still trigger GitHub Actions.
