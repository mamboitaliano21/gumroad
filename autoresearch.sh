#!/usr/bin/env bash
set -euo pipefail

# Autoresearch benchmark: run 5 sequential CI runs on GitHub and report average duration
REPO="antiwork/gumroad"
BRANCH="autoresearch/ci-speedup-2026-04-27"
NUM_RUNS=5
POLL_INTERVAL=30  # seconds between status checks

log() { echo "[autoresearch] $(date '+%H:%M:%S') $*"; }

# Push current branch state
log "Pushing branch $BRANCH..."
git push origin "$BRANCH" --force-with-lease 2>/dev/null || git push origin "$BRANCH"

# Wait for the push-triggered run to appear
sleep 10
FIRST_RUN_ID=$(gh run list --repo "$REPO" --branch "$BRANCH" --workflow tests.yml --limit 1 --json databaseId --jq '.[0].databaseId')
if [[ -z "$FIRST_RUN_ID" ]]; then
  log "ERROR: No CI run found after push"
  exit 1
fi
log "First run triggered: $FIRST_RUN_ID"

durations=()
pass_count=0
slowest_shard=0

run_and_measure() {
  local run_id=$1
  local run_num=$2

  log "Run $run_num/$NUM_RUNS: waiting for run $run_id..."

  # Wait for completion
  while true; do
    status=$(gh run view "$run_id" --repo "$REPO" --json status,conclusion --jq '.status')
    if [[ "$status" == "completed" ]]; then
      break
    fi
    sleep "$POLL_INTERVAL"
  done

  # Get conclusion and timing
  conclusion=$(gh run view "$run_id" --repo "$REPO" --json conclusion --jq '.conclusion')
  run_started=$(gh run view "$run_id" --repo "$REPO" --json createdAt --jq '.createdAt')
  run_ended=$(gh run view "$run_id" --repo "$REPO" --json updatedAt --jq '.updatedAt')

  # Calculate duration in minutes
  start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$run_started" "+%s" 2>/dev/null || date -d "$run_started" "+%s")
  end_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$run_ended" "+%s" 2>/dev/null || date -d "$run_ended" "+%s")
  duration_min=$(echo "scale=2; ($end_epoch - $start_epoch) / 60" | bc)

  # Get slowest test shard duration
  shard_max=$(gh api "/repos/$REPO/actions/runs/$run_id/jobs?per_page=100" \
    --jq '[.jobs[] | select(.name | startswith("Test")) | select(.conclusion == "success") |
      {s: .started_at, c: .completed_at}] |
      map(( (.c | sub("Z$";"") | split("T") | .[1] | split(":") | (.[0]|tonumber)*3600 + (.[1]|tonumber)*60 + (.[2]|tonumber)) -
           (.s | sub("Z$";"") | split("T") | .[1] | split(":") | (.[0]|tonumber)*3600 + (.[1]|tonumber)*60 + (.[2]|tonumber)) ) / 60) |
      max // 0' 2>/dev/null || echo "0")

  log "Run $run_num: conclusion=$conclusion duration=${duration_min}min slowest_shard=${shard_max}min"

  if [[ "$conclusion" == "success" ]]; then
    pass_count=$((pass_count + 1))
  fi

  durations+=("$duration_min")
  if (( $(echo "$shard_max > $slowest_shard" | bc -l) )); then
    slowest_shard="$shard_max"
  fi
}

# Run 1: the push-triggered run
run_and_measure "$FIRST_RUN_ID" 1

# Runs 2-5: re-run the workflow
for i in $(seq 2 $NUM_RUNS); do
  log "Triggering re-run $i/$NUM_RUNS..."
  gh run rerun "$FIRST_RUN_ID" --repo "$REPO" 2>/dev/null || {
    # If rerun fails, push an empty commit to trigger a new run
    log "Rerun failed, pushing empty commit..."
    git commit --allow-empty -m "ci: benchmark run $i"
    git push origin "$BRANCH"
    sleep 10
    FIRST_RUN_ID=$(gh run list --repo "$REPO" --branch "$BRANCH" --workflow tests.yml --limit 1 --json databaseId --jq '.[0].databaseId')
  }

  # Wait a moment for the rerun to register
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

log "Results: avg_duration=${avg}min pass_rate=${pass_rate}% slowest_shard=${slowest_shard}min"

# Output metrics for autoresearch
echo "METRIC ci_duration_min=$avg"
echo "METRIC pass_rate=$pass_rate"
echo "METRIC slowest_shard_min=$slowest_shard"
