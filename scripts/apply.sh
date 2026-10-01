#!/usr/bin/env bash
# Run one Resource Manager apply job and report the outcome.
# Exit 0 + done=false  -> failed only because of out-of-capacity (retry on next schedule)
# Exit 0 + done=false  -> also used when OCI rate-limits job creation (HTTP 429)
# Exit 0 + done=true   -> apply SUCCEEDED (workflow will disable itself)
# Exit 1               -> failed for another reason (needs a human)
set -u
: "${OCI_STACK_ID:?OCI_STACK_ID is required}"

# Keep stderr (waiter progress messages) out of the JSON on stdout.
errf=$(mktemp)
set +e
out=$(oci resource-manager job create-apply-job \
  --stack-id "$OCI_STACK_ID" \
  --execution-plan-strategy AUTO_APPROVED \
  --wait-for-state SUCCEEDED --wait-for-state FAILED \
  --max-wait-seconds 1500 2>"$errf")
set -e

state=$(echo "$out" | jq -r '.data."lifecycle-state" // empty' 2>/dev/null || true)
job_id=$(echo "$out" | jq -r '.data.id // empty' 2>/dev/null || true)
echo "job=$job_id state=$state"

if [ "$state" = "SUCCEEDED" ]; then
  echo "done=true" >> "$GITHUB_OUTPUT"
  exit 0
fi

if [ -z "$job_id" ]; then
  # OCI throttles job creation (HTTP 429); treat as transient and retry later.
  if grep -qE 'TooManyRequests|"status": 429' "$errf"; then
    echo "Rate limited by OCI (429). Will retry on the next schedule."
    echo "done=false" >> "$GITHUB_OUTPUT"
    exit 0
  fi
  echo "Could not create/parse the apply job. CLI output:"
  echo "$out"
  echo "--- stderr ---"
  cat "$errf"
  exit 1
fi

logs=$(oci resource-manager job get-job-logs-content --job-id "$job_id" 2>&1 || true)
if echo "$logs" | grep -qiE "out of (host )?capacity|OutOfHostCapacity"; then
  echo "Out of capacity. Will retry on the next schedule."
  echo "done=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

echo "Failed for a reason other than capacity:"
echo "$logs" | tail -n 40
exit 1
