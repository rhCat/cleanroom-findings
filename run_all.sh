#!/bin/bash
set -euo pipefail
export DOCKER_BUILDKIT=1
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "================================================================"
echo "  cleanroom-findings — run all cleanrooms"
echo "  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "================================================================"

declare -A RESULTS
run_test() {
    local name="$1" dir="findings/$1" tag="cleanroom-${1//_/-}"
    echo ""
    echo "--- $name ---"
    if ! docker build -q -t "$tag" "$dir" 2>/tmp/cleanroom_build_err; then
        echo "BUILD FAILED:"; tail -5 /tmp/cleanroom_build_err
        RESULTS[$name]="BUILD_FAILED"; return
    fi
    output=$(docker run --rm "$tag" 2>&1) || true
    echo "$output"
    if echo "$output" | grep -q "^CONTRADICTION"; then RESULTS[$name]="CONTRADICTION"
    elif echo "$output" | grep -q "^PASS"; then RESULTS[$name]="PASS"
    elif echo "$output" | grep -q "^NOT_CONFIRMED"; then RESULTS[$name]="NOT_CONFIRMED"
    else RESULTS[$name]="UNKNOWN"; fi
}

run_test git-hook-return-discard
run_test git-hook-return-discard-patch
# git-merge-ort-rename-pipeline-discard has no Dockerfile (documentation-only)
run_test git-merge-ort-rename-pipeline-discard-patch

echo ""
echo "================================================================"
echo "  SUMMARY"
echo "================================================================"
printf "%-50s %s\n" "TEST" "RESULT"
printf "%-50s %s\n" "--------------------------------------------------" "----------------"
for name in git-hook-return-discard git-hook-return-discard-patch git-merge-ort-rename-pipeline-discard-patch; do
    printf "%-50s %s\n" "$name" "${RESULTS[$name]:-SKIPPED}"
done
echo "================================================================"
