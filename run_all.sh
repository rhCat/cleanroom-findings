#!/usr/bin/env bash
set -euo pipefail
export DOCKER_BUILDKIT=1
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "================================================================"
echo "  cleanroom-findings — run all cleanrooms"
echo "  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "================================================================"

RESULTS=""

run_test() {
    local name="$1" dir="findings/$1" tag="cleanroom-${1}"
    echo ""
    echo "--- $name ---"
    if ! docker build -q -t "$tag" "$dir" 2>/tmp/cleanroom_build_err; then
        echo "BUILD FAILED:"; tail -5 /tmp/cleanroom_build_err
        RESULTS="$RESULTS\n$(printf '%-50s %s' "$name" BUILD_FAILED)"
        return
    fi
    output=$(docker run --rm "$tag" 2>&1) || true
    echo "$output"
    if echo "$output" | grep -q "^CONTRADICTION"; then result="CONTRADICTION"
    elif echo "$output" | grep -q "^PASS"; then result="PASS"
    elif echo "$output" | grep -q "^NOT_CONFIRMED"; then result="NOT_CONFIRMED"
    else result="UNKNOWN"; fi
    RESULTS="$RESULTS\n$(printf '%-50s %s' "$name" "$result")"
}

run_test git-hook-return-discard
run_test git-hook-return-discard-patch
# git-merge-ort-rename-pipeline-discard has no Dockerfile (documentation-only)
run_test git-merge-ort-rename-pipeline-discard-patch
# git-merge-ort-make-virtual-commit-error-discard has no Dockerfile (documentation-only)
run_test git-merge-ort-make-virtual-commit-error-discard-patch
run_test git-update-ref-parse-arg-inconsistency-patch
run_test curl-etag-save-write-discard
run_test curl-etag-save-write-discard-patch

echo ""
echo "================================================================"
echo "  SUMMARY"
echo "================================================================"
printf "%-50s %s\n" "TEST" "RESULT"
printf "%-50s %s\n" "--------------------------------------------------" "----------------"
echo -e "$RESULTS"
echo "================================================================"
