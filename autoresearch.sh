#!/usr/bin/env bash
set -euo pipefail

# Autoresearch benchmark: push branch, run 5 sequential CI runs, count green results
REPO="antiwork/gumroad"
BRANCH="autoresearch/ci-speedup-2026-04-27"
NUM_RUNS=5
POLL_INTERVAL=30

log() { echo "[bench] $(date '+%H:%M:%S') $*" >&2; }

# Pre-check: ensure we're on the right branch
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$current_branch" != "$BRANCH" ]]; then
  echo "ERROR: expected branch $BRANCH, got $current_branch" >&2
  exit 1
fi

# Push current state
log "Pushing $BRANCH..."
git push origin "$BRANCH" 2>&1 >&2 || true

green=0
total_failures=0

for i in $(seq 1 "$NUM_RUNS"); do
  if [[ $i -gt 1 ]]; then
    log "Pushing empty commit for run $i..."
    git commit --allow-empty -m "ci: autoresearch run $i" >/dev/null 2>&1
    git push origin "$BRANCH" 2>&1 >&2
  fi

  # Wait for run to appear
  sleep 20
  run_id=""
  for attempt in $(seq 1 12); do
    run_id=$(gh api "/repos/$REPO/actions/runs?per_page=5" \
      --jq "[.workflow_runs[] | select(.head_branch == \"$BRANCH\" and .name == \"Tests\" and .status != \"completed\")] | .[0].id // empty" 2>/dev/null)
    if [[ -n "$run_id" ]]; then break; fi
    sleep 10
  done

  if [[ -z "$run_id" ]]; then
    # Maybe it already completed very fast, grab the latest
    run_id=$(gh api "/repos/$REPO/actions/runs?per_page=3" \
      --jq "[.workflow_runs[] | select(.head_branch == \"$BRANCH\" and .name == \"Tests\")] | .[0].id // empty" 2>/dev/null)
  fi

  if [[ -z "$run_id" ]]; then
    log "Run $i: no CI run found, counting as failure"
    total_failures=$((total_failures + 1))
    continue
  fi

  log "Run $i: waiting for $run_id..."
  while true; do
    rs=$(gh api "/repos/$REPO/actions/runs/$run_id" --jq '.status' 2>/dev/null)
    if [[ "$rs" == "completed" ]]; then break; fi
    sleep "$POLL_INTERVAL"
  done

  conclusion=$(gh api "/repos/$REPO/actions/runs/$run_id" --jq '.conclusion' 2>/dev/null)
  if [[ "$conclusion" == "success" ]]; then
    green=$((green + 1))
    log "Run $i ($run_id): GREEN ✓"
  else
    # Count individual failed jobs
    failed_jobs=$(gh api "/repos/$REPO/actions/runs/$run_id/jobs?per_page=100&filter=latest" \
      --jq '[.jobs[] | select(.conclusion == "failure")] | length' 2>/dev/null || echo "1")
    total_failures=$((total_failures + failed_jobs))
    log "Run $i ($run_id): FAILED ($failed_jobs jobs failed)"
  fi
done

log "Results: $green/$NUM_RUNS green, $total_failures total job failures"
echo "METRIC green_runs=$green"
echo "METRIC total_failures=$total_failures"
