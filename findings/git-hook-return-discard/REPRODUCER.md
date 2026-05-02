# Reproducer and Impact Analysis

## Reproduction Script

```bash
#!/bin/bash
# Demonstrates that git reports success even when the reference-transaction
# hook fails on the "committed" phase.

set -e
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Set up bare remote
git init --bare "$TMPDIR/remote.git" -q

# Set up local repo
git init "$TMPDIR/local" -q
cd "$TMPDIR/local"
git remote add origin "$TMPDIR/remote.git"

# Create a commit
git commit --allow-empty -m "init" -q

# Install a hook on the remote that fails on "committed"
cat > "$TMPDIR/remote.git/hooks/reference-transaction" << 'HOOK'
#!/bin/sh
if [ "$1" = "committed" ]; then
    echo "HOOK: committed phase — simulating PR tracker failure" >&2
    exit 1   # non-zero = failure
fi
exit 0
HOOK
chmod +x "$TMPDIR/remote.git/hooks/reference-transaction"

# Push — should this fail?
echo "=== Pushing ==="
git push origin main 2>&1 || true

echo ""
echo "=== git push exit code: $? ==="
echo "(Expected: 0 — git reports SUCCESS despite hook failure)"
echo ""

# Verify ref was written
echo "=== Remote refs ==="
git -C "$TMPDIR/remote.git" show-ref
```

## Expected Behavior

- `git push` exits 0 (success)
- The ref IS written to remote (branch is updated)  
- Hook stderr shows "simulating PR tracker failure"
- No error message in git output about the hook failure
- A PR tracking system using this hook never learns about the push

## Observed Behavior (Actual)

Same as expected — git 2.34–2.49 all silently discard the "committed" phase
hook return value. The push succeeds, the ref is written, the hook failure
is invisible to the caller.

## Impact Analysis

**Direct impact**:
- Any `reference-transaction` hook that performs external side effects
  (webhook POST, database write, CI trigger) on the "committed" phase can
  fail silently, causing the side effect to be permanently missed.
- The hook is not retried. There is no retry mechanism in git's hook
  infrastructure.

**PR-disappear scenario**:
- A forge/hosting service uses `reference-transaction` to update PR state
  when a branch is pushed.
- The hook fails (network partition, service restart, rate limit).
- git returns success to the client.
- The push is complete and the branch is updated.
- The forge's PR database was never updated — the PR remains in its
  pre-push state (e.g., "open" when it should be "merged").
- No alert is raised because no error was propagated.

**Severity factors**:
- Affects ALL git deployments using reference-transaction hooks for
  external synchronization (common in self-hosted forge setups).
- Silent failure with no diagnostic path — the only way to detect is
  to diff the ref state against the external system.
- The "preparing"/"prepared" phases are correctly guarded, creating a
  false sense of completeness in the hook contract.

## Mitigation (Until Fixed)

Add a wrapper that logs hook failures separately:
```sh
#!/bin/sh
# reference-transaction wrapper with logging
set -e
/usr/local/lib/git-hooks/reference-transaction-impl "$@"
STATUS=$?
if [ $STATUS -ne 0 ]; then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) reference-transaction hook failed: phase=$1 status=$STATUS" \
        >> /var/log/git-hook-failures.log
fi
exit $STATUS
```
Note: this only helps if the forge reads the log; git itself still ignores
the exit code for "committed"/"aborted" phases.
