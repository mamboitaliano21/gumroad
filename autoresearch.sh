#!/usr/bin/env bash
set -euo pipefail

# Autoresearch benchmark: trigger CI on GitHub, wait for completion, report duration
# Usage: ./autoresearch.sh [num_runs]  (default: 1)
REPO="antiwork/gumroad"
BRANCH="autoresearch/ci-speedup-2026-04-27"
NUM_RUNS="${1:-1}"
POLL_INTERVAL=30

log() { echo "[autoresearch] $(date '+%H:%M:%S') $*"; }

# Push current branch state
log "Pushing branch $BRANCH..."
git push origin "$BRANCH" 2>&1 || git push origin "$BRANCH" --force-with-lease 2>&1

# Wait for the push-triggered run to appear
log "Waiting for CI run to appear..."
sleep 15

RUN_ID=""
for attempt in $(seq 1 10); do
  RUN_ID=$(gh run list --repo "$REPO" --branch "$BRANCH" --workflow tests.yml --limit 1 --json databaseId,status --jq '.[0].databaseId // empty')
  if [[ -n "$RUN_ID" ]]; then
    break
  fi
  log "No run found yet, retrying ($attempt/10)..."
  sleep 10
done

if [[ -z "$RUN_ID" ]]; then
  log "ERROR: No CI run found after push"
  exit 1
fi

durations=()
pass_count=0
slowest_shard=0

run_and_measure() {
  local run_id=$1
  local run_num=$2

  log "Run $run_num/$NUM_RUNS: waiting for run $run_id..."

  while true; do
    local status
    status=$(gh run view "$run_id" --repo "$REPO" --json status --jq '.status')
    if [[ "$status" == "completed" ]]; then
      break
    fi
    log "  status: $status"
    sleep "$POLL_INTERVAL"
  done

  local conclusion run_data start_ts end_ts start_epoch end_epoch duration_min
  run_data=$(gh run view "$run_id" --repo "$REPO" --json conclusion,createdAt,updatedAt)
  conclusion=$(echo "$run_data" | jq -r '.conclusion')
  start_ts=$(echo "$run_data" | jq -r '.createdAt')
  end_ts=$(echo "$run_data" | jq -r '.updatedAt')

  start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$start_ts" "+%s" 2>/dev/null || date -d "$start_ts" "+%s")
  end_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$end_ts" "+%s" 2>/dev/null || date -d "$end_ts" "+%s")
  duration_min=$(echo "scale=2; ($end_epoch - $start_epoch) / 60" | bc)

  log "Run $run_num: conclusion=$conclusion duration=${duration_min}min"

  if [[ "$conclusion" == "success" ]]; then
    pass_count=$((pass_count + 1))
  else
    log "WARNING: Run $run_num failed with conclusion=$conclusion"
  fi

  durations+=("$duration_min")
}

# Run 1: the push-triggered run
run_and_measure "$RUN_ID" 1

# Additional runs if requested
for i in $(seq 2 "$NUM_RUNS"); do
  log "Triggering run $i/$NUM_RUNS via empty commit..."
  git commit --allow-empty -m "ci: benchmark run $i"
  git push origin "$BRANCH"
  sleep 15

  NEW_RUN_ID=$(gh run list --repo "$REPO" --branch "$BRANCH" --workflow tests.yml --limit 1 --json databaseId --jq '.[0].databaseId')
  run_and_measure "$NEW_RUN_ID" "$i"
done

# Calculate average duration
total=0
for d in "${durations[@]}"; do
  total=$(echo "$total + $d" | bc)
done
avg=$(echo "scale=2; $total / ${#durations[@]}" | bc)
pass_rate=$(echo "scale=0; $pass_count * 100 / $NUM_RUNS" | bc)

log "Results: avg_duration=${avg}min pass_rate=${pass_rate}%"

echo "METRIC ci_duration_min=$avg"
echo "METRIC pass_rate=$pass_rate"
