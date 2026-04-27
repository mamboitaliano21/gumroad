#!/usr/bin/env bash
set -euo pipefail

# Autoresearch benchmark: check last 5 CI runs on the current branch.
# This script does NOT wait for CI - it reads completed results.
# Push changes and wait for CI to finish BEFORE running this.
REPO="antiwork/gumroad"
BRANCH=$(git rev-parse --abbrev-ref HEAD)

log() { echo "[bench] $*" >&2; }

# Get last 5 completed test runs on this branch
runs=$(gh api "/repos/$REPO/actions/workflows/tests.yml/runs?branch=$BRANCH&status=completed&per_page=5" \
  --jq '.workflow_runs | length' 2>/dev/null)

if [[ "$runs" -eq 0 ]]; then
  log "ERROR: No completed CI runs found on branch $BRANCH"
  echo "METRIC green_runs=0"
  echo "METRIC total_failures=99"
  exit 1
fi

green=0
total_failures=0

gh api "/repos/$REPO/actions/workflows/tests.yml/runs?branch=$BRANCH&status=completed&per_page=5" \
  --jq '.workflow_runs[] | "\(.id) \(.conclusion)"' 2>/dev/null | while read -r run_id conclusion; do
  if [[ "$conclusion" == "success" ]]; then
    green=$((green + 1))
    log "Run $run_id: GREEN"
  else
    failed=$(gh api "/repos/$REPO/actions/runs/$run_id/jobs?per_page=100&filter=latest" \
      --jq '[.jobs[] | select(.conclusion == "failure")] | length' 2>/dev/null || echo "1")
    total_failures=$((total_failures + failed))
    log "Run $run_id: FAILED ($failed jobs)"
  fi
  # Write to temp file since we're in a pipe
  echo "$green" > /tmp/ar_green
  echo "$total_failures" > /tmp/ar_failures
done

green=$(cat /tmp/ar_green 2>/dev/null || echo "0")
total_failures=$(cat /tmp/ar_failures 2>/dev/null || echo "0")

log "Results: $green/5 green, $total_failures total job failures"
echo "METRIC green_runs=$green"
echo "METRIC total_failures=$total_failures"
