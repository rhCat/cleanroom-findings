# syntax=docker/dockerfile:1
# Patch cleanroom: git-merge-ort make_virtual_commit NULL guard
#
# Bug cleanroom (docs-only, no wild reproducer):
#   findings/git-merge-ort-make-virtual-commit-error-discard/
#
# This Dockerfile:
#   1. Applies NULL guards to make_virtual_commit call sites in merge_ort_internal
#   2. Adds GIT_TEST_MAKE_VIRTUAL_COMMIT_FAIL test hook to exercise the guard
#   3. Verifies:
#      a. Normal criss-cross merge still works (no regression)
#      b. When hook fires, die() message appears instead of SIGSEGV
#
# The GIT_TEST_MAKE_VIRTUAL_COMMIT_FAIL hook is analogous to git's own
# GIT_TEST_* variables used throughout the test suite.

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

# Patch 1: add NULL guard to initial empty-tree ancestor allocation.
# Also inject test hook: on second call (loop body), return NULL to exercise guard.
import re

# Patch 1: add NULL guard to initial empty-tree ancestor allocation.
# Use regex for robustness across minor indentation differences.
m1 = re.search(
    r'(\t\tmerged_merge_bases = make_virtual_commit\(opt->repo, tree,\n'
    r'\t{7} "ancestor"\);\n)'
    r'(\t\tancestor_name = "empty tree";\n)',
    code)
if not m1:
    raise SystemExit('ERROR: patch1 target not found')
replacement1 = (
    m1.group(1) +
    '\t\t/* FIX: guard against allocator failure */\n'
    '\t\tif (!merged_merge_bases)\n'
    '\t\t\tdie(_("out of memory: make_virtual_commit failed (ancestor)"));\n' +
    m1.group(2)
)
code = code[:m1.start()] + replacement1 + code[m1.end():]
print('Patch 1 applied: NULL guard on ancestor allocation')

# Patch 2: add NULL guard to loop-body allocation (the dangerous path).
# Inject test hook so we can trigger the die() in tests.
m2 = re.search(
    r'(\t\tmerged_merge_bases = make_virtual_commit\(opt->repo,\n'
    r'\t{7} result->tree,\n'
    r'\t{7} "merged tree"\);\n)'
    r'(\t\tcommit_list_insert\(prev, &merged_merge_bases->parents\);\n)',
    code)
if not m2:
    raise SystemExit('ERROR: patch2 target not found')
replacement2 = (
    m2.group(1) +
    '\t\t/*\n'
    '\t\t * FIX + TEST HOOK: guard against NULL from make_virtual_commit.\n'
    '\t\t * GIT_TEST_MAKE_VIRTUAL_COMMIT_FAIL exercises this path.\n'
    '\t\t */\n'
    '\t\tif (getenv("GIT_TEST_MAKE_VIRTUAL_COMMIT_FAIL"))\n'
    '\t\t\tmerged_merge_bases = NULL;\n'
    '\t\tif (!merged_merge_bases)\n'
    '\t\t\tdie(_("out of memory: make_virtual_commit failed (merged tree)"));\n' +
    m2.group(2)
)
code = code[:m2.start()] + replacement2 + code[m2.end():]
print('Patch 2 applied: NULL guard on loop-body allocation + test hook')

with open('merge-ort.c', 'w') as f:
    f.write(code)
print('Patch applied: NULL guards at make_virtual_commit call sites')
PYEOF

RUN make configure && ./configure --prefix=/opt/git-patched --without-tcltk \
    && make -j$(nproc) NO_GETTEXT=1 install

FROM alpine:3.19
RUN apk add --no-cache bash libcurl openssl expat
COPY --from=builder /opt/git-patched /opt/git-patched
ENV PATH="/opt/git-patched/bin:$PATH"

RUN <<'SHEOF' cat > /test.sh
#!/bin/bash
# PATCH VERIFICATION TEST — NOT a wild bug reproducer.
# GIT_TEST_MAKE_VIRTUAL_COMMIT_FAIL exercises the NULL guard injected by the patch.
set -euo pipefail

git config --global user.email "test@test.com"
git config --global user.name "Test"
git config --global init.defaultBranch main
git config --global advice.detachedHead false

R=$(mktemp -d)/repo
trap "rm -rf $(dirname $R)" EXIT

setup_criss_cross() {
    # Build a criss-cross merge topology that forces recursive merge base reduction:
    #   A -- B (main)
    #    \  / \
    #     X    ?
    #    / \  /
    #   A -- C (side1)
    # where B and C share two common ancestors, triggering the merge-base loop.
    rm -rf "$R"
    git init "$R" -q && cd "$R"
    printf "base content\n" > file.txt
    git add file.txt && git commit -m "A: base" -q

    # branch1
    git checkout -b branch1 -q
    printf "branch1 change\n" >> file.txt
    git add file.txt && git commit -m "B: branch1 change" -q

    # branch2 from A
    git checkout main -q
    git checkout -b branch2 -q
    printf "branch2 change\n" >> file.txt
    git add file.txt && git commit -m "C: branch2 change" -q

    # criss-cross: merge branch1 into branch2 and branch2 into branch1
    git checkout branch1 -q
    git merge branch2 --no-commit -q 2>/dev/null || true
    printf "resolved\n" > file.txt
    git add file.txt && git commit -m "D: branch1 merged branch2" -q

    git checkout branch2 -q
    git merge branch1~1 --no-commit -q 2>/dev/null || true
    printf "resolved2\n" > file.txt
    git add file.txt && git commit -m "E: branch2 merged branch1 ancestor" -q
}

echo "================================================================"
echo "  GIT PATCH: merge-ort make_virtual_commit NULL guard"
echo "  Patch cleanroom — $(git --version) built from source with fix"
echo "================================================================"
echo ""

# ── TEST A: REGRESSION CHECK ────────────────────────────────────────────────

echo "── TEST A: Normal merge — regression check ──────────────────────────────"
echo "(no test hook — make_virtual_commit behaves normally)"
echo ""
setup_criss_cross
echo "$ git log --oneline --graph --all"
git log --oneline --graph --all
echo ""
echo "$ git merge branch1"
set +e
git merge branch1 2>&1
A_EXIT=$?
set -e
echo ""
echo "Exit: $A_EXIT"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

# ── TEST B: NULL GUARD PATH ─────────────────────────────────────────────────

echo "── TEST B: NULL guard — GIT_TEST_MAKE_VIRTUAL_COMMIT_FAIL=1 ────────────"
echo "(patch hook: forces make_virtual_commit to return NULL in loop body)"
echo "(patched code: die() fires instead of SIGSEGV)"
echo ""
setup_criss_cross
echo "$ GIT_TEST_MAKE_VIRTUAL_COMMIT_FAIL=1 git merge branch1"
set +e
GIT_TEST_MAKE_VIRTUAL_COMMIT_FAIL=1 git merge branch1 2>&1
B_EXIT=$?
set -e
echo ""
echo "Exit: $B_EXIT"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

# ── CONCLUSION ──────────────────────────────────────────────────────────────

echo "── CONCLUSION ───────────────────────────────────────────────────────────"
# A_EXIT: merge may exit 0 (clean) or 1 (conflict) — either is a non-crash
# B_EXIT: must be non-zero (die() exits 128) and must NOT be signal death (>128 via SIGSEGV = 139)
if [ $A_EXIT -le 1 ] && [ $B_EXIT -ne 0 ] && [ $B_EXIT -ne 139 ]; then
    echo ""
    echo "  Test A (normal merge):   exit=$A_EXIT — completed without crash (no regression)"
    echo "  Test B (NULL injected):  exit=$B_EXIT — die() fired, no SIGSEGV (NULL guard works)"
    echo ""
    echo "  The patch adds NULL guards at both make_virtual_commit call sites:"
    echo "    merge_ort_internal L5335 (ancestor): if (!merged_merge_bases) die()"
    echo "    merge_ort_internal L5374 (loop):     if (!merged_merge_bases) die()"
    echo ""
    echo "  Without the patch, the loop-body path would SIGSEGV (exit 139) because"
    echo "  commit_list_insert dereferences merged_merge_bases->parents immediately."
    echo ""
    echo "────────────────────────────────────────────────────────────────────────"
    echo ""
    echo "PASS (PATCHED): NULL guard fires correctly, no SIGSEGV"
    echo "  Test A exit=$A_EXIT (normal merge — no regression)"
    echo "  Test B exit=$B_EXIT (NULL guard: die() instead of SIGSEGV)"
    exit 0
else
    echo "  NOT_CONFIRMED: A=$A_EXIT B=$B_EXIT"
    echo "    (expected: A<=1, B!=0 and B!=139)"
    echo "────────────────────────────────────────────────────────────────────────"
    echo "NOT_CONFIRMED"
    exit 1
fi
SHEOF

CMD ["bash", "/test.sh"]
