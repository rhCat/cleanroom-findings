# syntax=docker/dockerfile:1
# Patch cleanroom: git-hook-return-discard fix
#
# Applies and verifies the minimal warning() patch to refs.c:
#   run_transaction_hook(transaction, "committed")
#   → if (run_transaction_hook(transaction, "committed"))
#         warning("reference-transaction hook failed for committed phase");
#
# This is the PATCH CLEANROOM. See the BUG CLEANROOM at:
#   cleanroom-mvp/git-hook-return-discard/
#   Dockerfile.git_ref_transaction_commit  (no source modification, stock git)
#
# Expected output: git push still exits 0, but the warning line now appears
# inline in the push output ("warning: reference-transaction hook failed
# for committed phase").
#
# Build from source: git 2.43.7 (same as Alpine 3.19 package)
FROM alpine:3.19 AS builder
RUN apk add --no-cache bash curl make gcc musl-dev \
    openssl-dev curl-dev expat-dev tar autoconf

RUN mkdir -p /usr/src \
    && curl -fsSL -o /tmp/git.tar.gz \
       https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.43.7.tar.gz \
    && tar -xz -C /usr/src/ -f /tmp/git.tar.gz \
    && mv /usr/src/git-2.43.7 /usr/src/git \
    && rm /tmp/git.tar.gz

WORKDIR /usr/src/git

# Apply the proposed warning() patch to refs.c
# Wraps the unchecked run_transaction_hook("committed") call with a
# return-value check that emits a warning on failure.
RUN sed -i \
    's/^\(\s*\)run_transaction_hook(transaction, "committed");/\1if (run_transaction_hook(transaction, "committed"))\n\1\twarning("reference-transaction hook failed for committed phase");/' \
    refs.c

RUN make configure && ./configure --prefix=/opt/git-patched --without-tcltk \
    && make -j$(nproc) NO_GETTEXT=1 install

FROM alpine:3.19
RUN apk add --no-cache bash libcurl openssl expat
COPY --from=builder /opt/git-patched /opt/git-patched
ENV PATH="/opt/git-patched/bin:$PATH"

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
echo "  GIT PATCH: reference-transaction hook 'committed' phase"
echo "             warning() added to surface hook failure"
echo "  Patch cleanroom — $(git --version) built from source with fix"
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
echo "Installing same hook as bug cleanroom (exits 1 on 'committed' phase):"
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
echo "Patch applied to refs.c:"
echo "  run_transaction_hook(transaction, \"committed\");"
echo "  → if (run_transaction_hook(transaction, \"committed\"))"
echo "        warning(\"reference-transaction hook failed for committed phase\");"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

# ── PUSH WITH PATCHED GIT ──────────────────────────────────────────────────

echo "── PUSH WITH PATCHED GIT ────────────────────────────────────────────────"
echo ""
echo "$ git commit --allow-empty -m 'add feature'"
git commit --allow-empty -m "add feature"
echo ""
echo "Pushing local branch to a distinct remote branch name."
echo "With the patch, git calls warning() when the hook returns non-zero."
echo "Watch for 'warning: reference-transaction hook failed' below:"
echo ""
PUSH_LOG=$(mktemp)
echo "$ git push origin hook-test-local:hook-test-remote"
set +e
git push origin hook-test-local:hook-test-remote 2>&1 | tee "$PUSH_LOG"
PUSH_EXIT=${PIPESTATUS[0]}
set -e
echo ""
echo "Exit: $PUSH_EXIT"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

# ── VERIFICATION ────────────────────────────────────────────────────────────

echo "── VERIFICATION ─────────────────────────────────────────────────────────"
echo ""
echo "Ref was written (push succeeded — 'committed' phase is post-write):"
echo ""
echo "$ git -C $REMOTE log hook-test-remote --oneline"
git -C "$REMOTE" log hook-test-remote --oneline
REF=$(git -C "$REMOTE" show-ref --verify refs/heads/hook-test-remote 2>/dev/null || true)
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

# ── CONCLUSION ──────────────────────────────────────────────────────────────

echo "── CONCLUSION ───────────────────────────────────────────────────────────"
HAS_WARNING=$(grep -ic "warning.*hook\|warning.*committed" "$PUSH_LOG" || true)
rm -f "$PUSH_LOG"

if [ "$HAS_WARNING" -gt 0 ] && [ -n "$REF" ]; then
    echo ""
    echo "  PUSH RESULT   : success (exit $PUSH_EXIT, hook-test-remote ref written)"
    echo "  HOOK RESULT   : failed (hook returned 1 on 'committed' phase)"
    echo "  WARNING EMITTED: YES — 'warning: reference-transaction hook failed' above"
    echo ""
    echo "  With the patch, refs.c now checks the return value of"
    echo "  run_transaction_hook(\"committed\") and emits a warning when it fails."
    echo "  git push still exits 0 because the ref WAS written — the 'committed'"
    echo "  phase fires after the write, so the push itself succeeded."
    echo "  The warning surfaces the hook failure to the user and to logs."
    echo ""
    echo "────────────────────────────────────────────────────────────────────────"
    echo ""
    echo "PASS (PATCHED): git push exited $PUSH_EXIT and emitted warning about hook failure -- patch verified"
    exit 0
else
    echo "  NOT_CONFIRMED: warning_found=$HAS_WARNING ref=${REF:-none}"
    echo "────────────────────────────────────────────────────────────────────────"
    echo "NOT_CONFIRMED: push succeeded silently -- patch may not have applied"
    exit 1
fi
SHEOF

CMD ["bash", "/test.sh"]
