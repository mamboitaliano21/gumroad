# Autoresearch: Fix Flaky CI Tests

## Objective
Eliminate flaky tests in the antiwork/gumroad repo so that CI (tests.yml workflow) passes on the first run consistently. The benchmark is 5 consecutive green CI runs on GitHub Actions. The metric is the number of green runs out of 5. Target: 5/5.

The test suite has 85 parallel shards (20 fast + 65 slow) running on Ubicloud runners with Knapsack Pro distribution. Tests are RSpec: unit/model specs, controller specs, and system/request specs (Capybara with JS).

## Metrics
- **Primary**: green_runs (count out of 5, higher is better)
- **Secondary**: total_failures

## How to Run
`./autoresearch.sh` — pushes branch, triggers 5 sequential CI runs on GitHub, waits for each, counts green runs, outputs `METRIC green_runs=N` and `METRIC total_failures=N`.

## Files in Scope
Only `*_spec.rb` files. Key flaky tests identified from recent CI failures:

**Frequent flakers (multiple failures across recent runs):**
- `spec/sidekiq/schedule_membership_price_updates_job_spec.rb:159` — non-deterministic MySQL ordering of plan changes with identical timestamps
- `spec/requests/embed_spec.rb:89,115,143` — Capybara timing issues in iframe-based system tests

**One-off flakers (single failure each, likely timing or state):**
- `spec/requests/products/edit/edit_spec.rb:681` — discover notices
- `spec/requests/workflows_spec.rb:1293` — publishing workflow eligibility
- `spec/requests/emails/edit_spec.rb:170` — editing/publishing email
- `spec/requests/library_spec.rb:267` — listing multiple purchases
- `spec/requests/products/index_spec.rb:169` — duplication loading state
- `spec/requests/products/creation_spec.rb:116` — physical product creation
- `spec/requests/affiliates_spec.rb:7` — affiliate redirect + discount
- `spec/requests/products/edit/rich_text_editor_spec.rb:314` — external link click
- `spec/requests/balance_pages_spec.rb:952` — suspended payout banner
- `spec/requests/purchases/product/offer_codes_spec.rb:89` — percentage discount checkout
- `spec/requests/products/collabs_spec.rb:184` — collabs placeholder
- `spec/helpers/installments_helper_spec.rb:13` — post title display
- `spec/sidekiq/sync_stuck_payouts_job_spec.rb:125` — stuck payouts sync

## Off Limits
- Application code (`app/`, `lib/`, `config/`)
- CI workflow (`.github/workflows/`)
- Test infrastructure (`spec/spec_helper.rb`, `spec/rails_helper.rb`, `spec/support/`)
- VCR cassettes (`spec/support/fixtures/`)

## Constraints
- All existing tests must still pass (no removing/skipping tests)
- Test coverage cannot decrease
- Only `*_spec.rb` files may be modified
- Cannot add new gem dependencies
- Common flaky test patterns to fix: missing Capybara waits, non-deterministic DB ordering, race conditions in async operations, time-dependent assertions

## What's Been Tried
_(Will be updated by the autoresearch plugin)_
