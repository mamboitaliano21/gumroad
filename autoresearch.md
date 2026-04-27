# Autoresearch: Optimize Gumroad CI Test Duration

## Objective
Reduce the wall-clock duration of the `tests.yml` GitHub Actions CI workflow for the antiwork/gumroad repo. The workflow builds Docker images, then runs RSpec tests in parallel shards: 20 "fast" shards (non-request specs) and 65 "slow" shards (request specs). Knapsack Pro handles test distribution. The bottleneck is typically the slowest `test_slow` shard.

We can ONLY modify test files (`spec/**/*_spec.rb`). The goal is to make tests run faster through optimization of the specs themselves (reducing setup overhead, removing redundant work, using lighter factories, etc.) without reducing test coverage.

## Metrics
- **Primary**: ci_duration_min (min, lower is better)
- **Secondary**: pass_rate, slowest_shard_min

## How to Run
`./autoresearch.sh` — pushes branch, triggers 5 sequential CI runs on GitHub, waits for completion, outputs `METRIC name=number` lines for average duration and pass rate.

## Files in Scope
ALL test files under `spec/` — only `*_spec.rb` files may be modified. Key targets by size:

**Request specs (slow shards, 65 shards):**
- `spec/requests/settings/payments_spec.rb` (6665 lines) — largest request spec
- `spec/requests/purchases/product/taxes_spec.rb` (4071 lines)
- `spec/requests/customers/customers_spec.rb` (1730 lines)
- `spec/requests/workflows_spec.rb` (1662 lines)
- `spec/requests/products/edit/rich_text_editor_spec.rb` (1438 lines)

**Non-request specs (fast shards, 20 shards):**
- `spec/business/payments/merchant_registration/stripe/stripe_merchant_account_manager_spec.rb` (11469 lines)
- `spec/models/purchase_spec.rb` (6476 lines)
- `spec/models/link_spec.rb` (4962 lines)
- `spec/controllers/links_controller_spec.rb` (4550 lines)
- `spec/models/subscription_spec.rb` (4153 lines)

## Off Limits
- **Application code** — no changes to `app/`, `lib/`, `config/`, etc.
- **CI workflow** — no changes to `.github/workflows/`
- **Test infrastructure** — no changes to `spec/spec_helper.rb`, `spec/rails_helper.rb`, `spec/support/` (factories, shared contexts, etc.)
- **VCR cassettes** — no changes to `spec/support/fixtures/`
- **Coverage cannot decrease** — all existing tests must still exist and pass

## Constraints
- All 5 CI runs must be green (pass) for the experiment to count
- Test coverage must remain the same or better
- Only `*_spec.rb` files may be modified
- Cannot add new gem dependencies
- Cannot remove test cases — only optimize how they run
- Cannot use `skip` or `:skip` tags to bypass tests
- Knapsack Pro handles shard distribution; focus on making individual tests faster

## What's Been Tried
_(Baseline pending — first run will establish this)_
