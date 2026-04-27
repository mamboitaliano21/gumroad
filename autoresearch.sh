#!/usr/bin/env bash
set -euo pipefail

# Autoresearch benchmark: check last 5 CI runs on the current branch.
# This script does NOT wait for CI - it reads completed results.
REPO="antiwork/gumroad"
BRANCH=$(git rev-parse --abbrev-ref HEAD)

log() { echo "[bench] $*" >&2; }

# GitHub API branch filter is unreliable with slashes, so we fetch more runs and filter locally
green=0
total_failures=0
count=0

gh api "/repos/$REPO/actions/workflows/tests.yml/runs?status=completed&per_page=30" \
  --jq ".workflow_runs[] | select(.head_branch == \"$BRANCH\") | \"\(.id) \(.conclusion)\"" 2>/dev/null | head -5 | while read -r run_id conclusion; do
  count=$((count + 1))
  if [[ "$conclusion" == "success" ]]; then
    green=$((green + 1))
    log "Run $run_id: GREEN"
  elif [[ "$conclusion" == "cancelled" ]]; then
    log "Run $run_id: CANCELLED (skipping)"
    count=$((count - 1))
  else
    failed=$(gh api "/repos/$REPO/actions/runs/$run_id/jobs?per_page=100&filter=latest" \
      --jq '[.jobs[] | select(.conclusion == "failure")] | length' 2>/dev/null || echo "1")
    total_failures=$((total_failures + failed))
    log "Run $run_id: FAILED ($failed jobs)"
  fi
  echo "$green" > /tmp/ar_green
  echo "$total_failures" > /tmp/ar_failures
  echo "$count" > /tmp/ar_count
done

green=$(cat /tmp/ar_green 2>/dev/null || echo "0")
total_failures=$(cat /tmp/ar_failures 2>/dev/null || echo "0")
count=$(cat /tmp/ar_count 2>/dev/null || echo "0")

log "Results: $green/$count green, $total_failures total job failures"
echo "METRIC green_runs=$green"
echo "METRIC total_failures=$total_failures"
