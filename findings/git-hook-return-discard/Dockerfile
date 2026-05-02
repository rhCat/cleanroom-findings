# syntax=docker/dockerfile:1
# Bug cleanroom: git reference-transaction hook 'committed' phase return discarded
#
# Stock unmodified git — no source modification.
# The hook writes to stderr; for a local push git-receive-pack stderr flows
# directly to the client's stderr (not prefixed with "remote:").
# The CONTRADICTION: hook ERROR lines visible, but git push exits 0.
#
# See patch cleanroom: Dockerfile.patch_git_ref_transaction_commit

FROM alpine:3.19
RUN apk add --no-cache git bash
RUN <<'SHEOF' cat > /test.sh
#!/bin/bash
set -euo pipefail
REMOTE=$(mktemp -d)/remote.git
WORK=$(mktemp -d)/work
trap "rm -rf $(dirname $REMOTE) $(dirname $WORK)" EXIT

git config --global user.email "test@test.com"
git config --global user.name "Test"
git config --global init.defaultBranch hook-test-local
git config --global advice.detachedHead false

echo "================================================================"
echo "  GIT BUG: reference-transaction hook 'committed' phase"
echo "           return value silently discarded"
echo "  Cleanroom — stock unmodified $(git --version)"
echo "================================================================"
echo ""

# ── SETUP ──────────────────────────────────────────────────────────────────

echo "── SETUP ────────────────────────────────────────────────────────────────"
echo ""
echo "$ git init --bare $REMOTE"
git init --bare "$REMOTE"
echo ""
echo "$ git init $WORK"
git init "$WORK"
cd "$WORK"
echo "$ git remote add origin $REMOTE"
git remote add origin "$REMOTE"
echo ""
echo "Installing reference-transaction hook on remote."
echo "The hook exits 1 on the 'committed' phase to simulate a CI tracker"
echo "that is unreachable after the ref is already written:"
echo ""
cat > "$REMOTE/hooks/reference-transaction" <<'HOOK'
#!/bin/sh
# Simulates a CI/webhook side-effect that fails after ref is already written.
echo "[hook] phase=$1 invoked" >&2
if [ "$1" = "committed" ]; then
    echo "[hook] ERROR: committed phase -- tracker unreachable, returning 1" >&2
    exit 1
fi
echo "[hook] OK" >&2
exit 0
HOOK
chmod +x "$REMOTE/hooks/reference-transaction"
echo "Hook script ($REMOTE/hooks/reference-transaction):"
cat "$REMOTE/hooks/reference-transaction"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

# ── BUG DEMONSTRATION ──────────────────────────────────────────────────────

echo "── BUG DEMONSTRATION ────────────────────────────────────────────────────"
echo ""
echo "$ git commit --allow-empty -m 'add feature'"
git commit --allow-empty -m "add feature"
echo ""
echo "Pushing local branch to a distinct remote branch name."
echo "Hook stderr flows through to the terminal alongside git's own output."
echo "Watch for '[hook] ERROR' below, then check the exit code:"
echo ""
echo "$ git push origin hook-test-local:hook-test-remote"
set +e
git push origin hook-test-local:hook-test-remote 2>&1
PUSH_EXIT=$?
set -e
echo ""
echo "Exit: $PUSH_EXIT"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

# ── VERIFICATION ────────────────────────────────────────────────────────────

echo "── VERIFICATION ─────────────────────────────────────────────────────────"
echo ""
echo "Was the ref written despite the hook error?"
echo ""
echo "$ git -C $REMOTE log hook-test-remote --oneline"
git -C "$REMOTE" log hook-test-remote --oneline
REF=$(git -C "$REMOTE" show-ref --verify refs/heads/hook-test-remote 2>/dev/null || true)
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

# ── CONCLUSION ──────────────────────────────────────────────────────────────

echo "── CONCLUSION ───────────────────────────────────────────────────────────"
if [ $PUSH_EXIT -eq 0 ] && [ -n "$REF" ]; then
    echo ""
    echo "  PUSH RESULT : success (exit $PUSH_EXIT, hook-test-remote ref written)"
    echo "  HOOK RESULT : failed  (hook returned 1 on 'committed' phase)"
    echo "                see '[hook] ERROR' in push output above"
    echo ""
    echo "  CONTRADICTION: git push reported success and wrote the ref,"
    echo "  but the hook's side-effect (CI notification, webhook) failed silently."
    echo "  refs.c calls run_transaction_hook(transaction, \"committed\") without"
    echo "  checking the return value. The push caller sees exit 0, no warning."
    echo ""
    echo "  In production: a CI trigger, webhook, or PR tracker that uses the"
    echo "  reference-transaction hook 'committed' phase silently misses updates."
    echo "  git reports success. No warning. No log entry. No retry."
    echo ""
    echo "────────────────────────────────────────────────────────────────────────"
    echo ""
    echo "CONTRADICTION: git push exited $PUSH_EXIT and ref was written, but reference-transaction hook failed on 'committed' phase -- side-effects silently discarded (refs.c run_transaction_hook return unchecked)"
    exit 0
else
    echo "  NOT_CONFIRMED: push=$PUSH_EXIT ref=${REF:-none}"
    echo "────────────────────────────────────────────────────────────────────────"
    echo "NOT_CONFIRMED"
    exit 1
fi
SHEOF

CMD ["bash", "/test.sh"]
