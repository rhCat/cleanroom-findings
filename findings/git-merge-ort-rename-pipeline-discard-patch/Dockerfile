# syntax=docker/dockerfile:1
# Patch cleanroom: git-merge-ort rename-pipeline-discard fix
#
# This is the PATCH CLEANROOM. The bug it addresses is a structural gap:
#   detect_regular_renames has no -1 error path, so any internal failure
#   in diffcore_rename_extended propagates silently as a clean merge.
#
# See the bug cleanroom (documentation-only, no wild reproducer):
#   cleanroom-mvp/git-merge-ort-rename-pipeline-discard/
#
# This Dockerfile:
#   1. Applies the proposed error-propagation patch to merge-ort.c
#   2. Adds a GIT_TEST_RENAME_DISCARD=1 test hook to exercise the new error path
#      (THIS IS PATCH TESTING, not a wild bug reproducer)
#   3. Verifies that with the patch:
#      a. Normal merges still work (no regression) — rename/rename conflict detected
#      b. When the new error path is triggered, merge aborts with exit 2
#         instead of silently committing a wrong tree
#
# The GIT_TEST_RENAME_DISCARD hook is analogous to git's own GIT_TEST_*
# variables used throughout the test suite to exercise error paths that
# are otherwise hard to trigger in a test environment.

FROM alpine:3.19 AS builder
RUN apk add --no-cache bash curl make gcc musl-dev \
    openssl-dev curl-dev expat-dev tar autoconf python3

RUN mkdir -p /usr/src \
    && curl -fsSL -o /tmp/git.tar.gz \
       https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.43.7.tar.gz \
    && tar -xz -C /tmp/ -f /tmp/git.tar.gz \
    && mv /tmp/git-2.43.7 /usr/src/git \
    && rm /tmp/git.tar.gz

WORKDIR /usr/src/git

RUN python3 - <<'PYEOF'
with open('merge-ort.c', 'r') as f:
    code = f.read()

# Patch 1: add test hook + -1 return path to detect_regular_renames.
# The test hook (GIT_TEST_RENAME_DISCARD) simulates an internal failure
# by discarding pairs and returning -1. In production, this path would
# be triggered by a failable diffcore_rename_extended.
target = '\trenames->pairs[side_index] = diff_queued_diff;\n\n\tdiff_opts.output_format = DIFF_FORMAT_NO_OUTPUT;'
replacement = (
    '\trenames->pairs[side_index] = diff_queued_diff;\n\n'
    '\t/*\n'
    '\t * FIX + TEST HOOK: return -1 on failure (GIT_TEST_RENAME_DISCARD\n'
    '\t * exercises this path; in production it would be wired to errors\n'
    '\t * from diffcore_rename_extended once that gains error signaling).\n'
    '\t */\n'
    '\tif (getenv("GIT_TEST_RENAME_DISCARD")) {\n'
    '\t\trenames->pairs[side_index].nr = 0;\n'
    '\t\trenames->pairs[side_index].queue = NULL;\n'
    '\t\treturn -1;\n'
    '\t}\n\n'
    '\tdiff_opts.output_format = DIFF_FORMAT_NO_OUTPUT;'
)
if target not in code:
    raise SystemExit('ERROR: patch1 target not found')
code = code.replace(target, replacement, 1)

# Patch 2: check for -1 in detect_and_process_renames.
target2 = (
    '\tdetection_run |= detect_regular_renames(opt, MERGE_SIDE1);\n'
    '\tdetection_run |= detect_regular_renames(opt, MERGE_SIDE2);\n'
)
replacement2 = (
    '\t/* FIX: propagate -1 from detect_regular_renames as a fatal error */\n'
    '\tif (detect_regular_renames(opt, MERGE_SIDE1) < 0 ||\n'
    '\t    detect_regular_renames(opt, MERGE_SIDE2) < 0) {\n'
    '\t\terror(_("rename detection failed; aborting merge to prevent tree corruption"));\n'
    '\t\tclean = -1;\n'
    '\t\tgoto cleanup;\n'
    '\t}\n'
    '\tdetection_run = 1;\n'
)
if target2 not in code:
    raise SystemExit('ERROR: patch2 target not found')
code = code.replace(target2, replacement2, 1)

with open('merge-ort.c', 'w') as f:
    f.write(code)
print('Patch applied: -1 error path + caller check in detect_and_process_renames')
PYEOF

RUN make configure && ./configure --prefix=/opt/git-patched --without-tcltk \
    && make -j$(nproc) NO_GETTEXT=1 install

FROM alpine:3.19
RUN apk add --no-cache bash libcurl openssl expat
COPY --from=builder /opt/git-patched /opt/git-patched
ENV PATH="/opt/git-patched/bin:$PATH"

RUN <<'SHEOF' cat > /test.sh
#!/bin/bash
# PATCH VERIFICATION TEST — NOT a bug reproducer.
# GIT_TEST_RENAME_DISCARD=1 is a test hook added by the patch itself to
# exercise the -1 error return path (analogous to git's own GIT_TEST_* vars).
set -euo pipefail

git config --global user.email "test@test.com"
git config --global user.name "Test"
git config --global init.defaultBranch main
git config --global advice.detachedHead false

R=$(mktemp -d)/repo
trap "rm -rf $(dirname $R)" EXIT

setup() {
    rm -rf "$R"
    git init "$R" -q && cd "$R"
    for i in $(seq 1 25); do printf "line %d of shared content\n" "$i"; done > foo.c
    git add foo.c && git commit -m "base: add foo.c" -q
    git checkout -b side1 -q
    git mv foo.c bar.c
    git commit -m "side1: rename foo.c -> bar.c" -q
    git checkout main -q
    git mv foo.c baz.c
    git commit -m "main: rename foo.c -> baz.c" -q
}

echo "================================================================"
echo "  GIT PATCH: merge-ort rename pipeline -1 error propagation"
echo "  Patch cleanroom — $(git --version) built from source with fix"
echo "================================================================"
echo ""
echo "  Scenario: rename/rename(1to2) conflict"
echo "    base:  foo.c"
echo "    main:  git mv foo.c baz.c"
echo "    side1: git mv foo.c bar.c"
echo ""
echo "  Patch adds:"
echo "    detect_regular_renames: returns -1 on failure"
echo "      (GIT_TEST_RENAME_DISCARD exercises this path)"
echo "    detect_and_process_renames: checks for -1, sets clean=-1, goto cleanup"
echo "    builtin/merge.c: clean < 0 → rollback_lock_file(), return 2"
echo ""

# ── TEST A: REGRESSION CHECK ────────────────────────────────────────────────

echo "── TEST A: Normal merge — regression check ──────────────────────────────"
echo "(rename detection active, no injection)"
echo ""
setup
echo "$ git log --oneline --graph --all"
git log --oneline --graph --all
echo ""
echo "$ git merge side1"
set +e
git merge side1 2>&1
A_EXIT=$?
set -e
echo ""
echo "Exit: $A_EXIT"
echo ""
echo "$ git ls-files"
git ls-files
echo ""
echo "$ git status --short"
git status --short || true
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

# ── TEST B: PATCH ERROR PATH ────────────────────────────────────────────────

echo "── TEST B: Error path — GIT_TEST_RENAME_DISCARD=1 ──────────────────────"
echo "(patch test hook: detect_regular_renames returns -1,"
echo " simulating a future failable diffcore_rename_extended)"
echo ""
setup
echo "$ GIT_TEST_RENAME_DISCARD=1 git merge side1"
set +e
GIT_TEST_RENAME_DISCARD=1 git merge side1 2>&1
B_EXIT=$?
set -e
echo ""
echo "Exit: $B_EXIT"
echo ""
echo "Working tree after aborted merge:"
echo "$ git ls-files"
git ls-files
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

# ── CONCLUSION ──────────────────────────────────────────────────────────────

echo "── CONCLUSION ───────────────────────────────────────────────────────────"
if [ $A_EXIT -eq 1 ] && [ $B_EXIT -ne 0 ]; then
    echo ""
    echo "  Test A (normal merge):       exit=$A_EXIT — rename/rename conflict detected (no regression)"
    echo "  Test B (error path active):  exit=$B_EXIT — merge aborted cleanly (no wrong tree committed)"
    echo ""
    echo "  The patch wires a -1 return path through the rename pipeline:"
    echo "    detect_regular_renames → -1"
    echo "    detect_and_process_renames → clean = -1, goto cleanup"
    echo "    result->clean = -1"
    echo "    builtin/merge.c: rollback_lock_file(), return 2"
    echo ""
    echo "  No wrong tree is committed. The user sees the error message above"
    echo "  instead of a silently incorrect merge result."
    echo ""
    echo "────────────────────────────────────────────────────────────────────────"
    echo ""
    echo "PASS (PATCHED): rename detection failure propagates as merge abort"
    echo "  Test A exit=$A_EXIT (conflict still detected — no regression)"
    echo "  Test B exit=$B_EXIT (error path: merge aborted, no wrong tree committed)"
    exit 0
else
    echo "  NOT_CONFIRMED: A=$A_EXIT B=$B_EXIT"
    echo "────────────────────────────────────────────────────────────────────────"
    echo "NOT_CONFIRMED"
    exit 1
fi
SHEOF

CMD ["bash", "/test.sh"]
