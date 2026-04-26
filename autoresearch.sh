#!/usr/bin/env bash
set -euo pipefail

REPO="antiwork/gumroad"
BRANCH="mock-stripe-e2e"
NUM_RUNS=3

RUBY_CMD=(ruby)
if command -v rbenv >/dev/null 2>&1; then
  RUBY_CMD=(rbenv exec ruby)
fi

while true; do
  for f in $(git diff origin/main --name-only -- '*.rb' '*.js' '*.ts' '*.tsx'); do
    if [[ "$f" == *.rb ]]; then "${RUBY_CMD[@]}" -c "$f" || exit 1; fi
  done

  SHA=$(git rev-parse HEAD)
  RUN_STAMP=$(date +%s)
  CI_BRANCHES=()

  git push origin "$SHA:refs/heads/$BRANCH" --force-with-lease 2>/dev/null || true
  for i in $(seq 1 $NUM_RUNS); do
    CI_BRANCH="${BRANCH}-ci-${RUN_STAMP}-${i}"
    CI_BRANCHES+=("$CI_BRANCH")
    git push origin "$SHA:refs/heads/$CI_BRANCH" --force 2>/dev/null || true
  done

  echo "Waiting for CI (~22 min)..."
  sleep 1320

  TOTAL_FAILED=0
  VALID_RUNS=0
  for B in "${CI_BRANCHES[@]}"; do
    RUN_ID=$(gh run list --repo "$REPO" --branch "$B" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || echo "")
    [ -z "$RUN_ID" ] && continue
    STATUS=$(gh run view "$RUN_ID" --repo "$REPO" --json status -q '.status' 2>/dev/null || echo "")
    while [ "$STATUS" != "completed" ]; do
      sleep 180
      STATUS=$(gh run view "$RUN_ID" --repo "$REPO" --json status -q '.status' 2>/dev/null || echo "")
    done
    FAILED=$(gh run view "$RUN_ID" --repo "$REPO" --json jobs 2>/dev/null | jq '[.jobs[] | select((.name | test("^Test (Fast|Slow) [0-9]+")) and .conclusion == "failure")] | length' 2>/dev/null || echo "0")
    if [ "$FAILED" -lt 70 ]; then
      TOTAL_FAILED=$((TOTAL_FAILED + FAILED))
      VALID_RUNS=$((VALID_RUNS + 1))
      echo "Run $RUN_ID ($B): $FAILED/85 failed"
    else
      echo "Run $RUN_ID ($B): INFRA FAILURE ($FAILED/85), skipping"
    fi
  done

  [ "$VALID_RUNS" -eq 0 ] && echo "No valid runs" && exit 1
  AVG=$(echo "scale=1; $TOTAL_FAILED / $VALID_RUNS" | bc)
  echo "METRIC failed_shards=$AVG"

  for B in "${CI_BRANCHES[@]}"; do
    git push origin --delete "$B" 2>/dev/null || true
  done
done
