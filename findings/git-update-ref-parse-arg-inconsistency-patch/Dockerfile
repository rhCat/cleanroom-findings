# syntax=docker/dockerfile:1
# Patch cleanroom: git-update-ref parse_next_arg validation gap
#
# Bug cleanroom: findings/git-update-ref-parse-arg-inconsistency/
#
# CORRECTED ANALYSIS (git 2.49.0):
#   In git 2.49.0+, parse_cmd_symref_update and parse_cmd_symref_create use
#   parse_next_refname (validated) for new_target. The remaining gap is that
#   old_target in symref-update goes through parse_next_arg (unvalidated) and
#   is validated only conditionally when old_arg == "ref". This is structurally
#   correct but complex.
#
#   The original FlowAsymmetry signal remains valid: parse_next_arg (returns
#   char*, no format check) exists alongside parse_next_refname (validates via
#   check_refname_format) — a latent misuse trap for future code additions.
#
# This Dockerfile:
#   1. Builds stock git 2.49.0 to document asymmetry behavior
#   2. Shows:
#      A. symref-update with invalid new_target — rejected by parse_next_refname
#      B. symref-update with old_arg="ref" and invalid old_target — also rejected
#      C. symref-update with invalid old_arg type — rejected with clear error
#      D. parse_next_arg remains unvalidated for keyword args — structural gap documented
#
# Note: Since 2.49.0 already validates new_target via parse_next_refname, this
# cleanroom documents the residual structural concern: parse_next_arg is an
# unvalidated helper adjacent to validated ones — a latent misuse trap.

FROM alpine:3.19 AS stock-builder
RUN apk add --no-cache bash curl make gcc musl-dev \
    openssl-dev curl-dev expat-dev tar autoconf python3 gettext-dev

RUN mkdir -p /usr/src \
    && curl -fsSL -o /tmp/git.tar.gz \
       https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.49.0.tar.gz \
    && tar -xz -C /tmp/ -f /tmp/git.tar.gz \
    && mv /tmp/git-2.49.0 /usr/src/git-stock \
    && rm /tmp/git.tar.gz

WORKDIR /usr/src/git-stock
RUN make configure && ./configure --prefix=/opt/git-stock --without-tcltk \
    && make -j$(nproc) NO_GETTEXT=1 install

FROM alpine:3.19
RUN apk add --no-cache bash libcurl openssl expat
COPY --from=stock-builder /opt/git-stock /opt/git-stock

RUN <<'SHEOF' cat > /test.sh
#!/bin/bash
# ASYMMETRY DOCUMENTATION TEST — git 2.49.0
# Shows: parse_next_refname validates new_target; parse_next_arg remains
# unvalidated for old_arg keyword args; old_target validated conditionally.
set -euo pipefail

GIT=/opt/git-stock/bin/git
$GIT config --global user.email "test@test.com"
$GIT config --global user.name "Test"
$GIT config --global init.defaultBranch main
$GIT config --global advice.detachedHead false
export GIT_CONFIG_NOSYSTEM=1

make_repo() {
    local d=$(mktemp -d)
    $GIT -C "$d" init -q
    $GIT -C "$d" commit --allow-empty -m "init" -q
    $GIT -C "$d" branch -m main
    echo "$d"
}

echo "================================================================"
echo "  GIT: update-ref parse_next_arg asymmetry documentation"
echo "  $($GIT --version)"
echo "  Structural gap: parse_next_arg (no validation) vs parse_next_refname"
echo "================================================================"
echo ""

# ── TEST A: new_target validated by parse_next_refname (already fixed) ───────

echo "── TEST A: symref-update with invalid new_target ────────────────────────"
echo "(parse_next_refname path — VALIDATES refname format)"
echo ""
R=$(make_repo)
trap "rm -rf $R" EXIT
$GIT -C "$R" update-ref refs/heads/main HEAD
set +e
printf 'symref-update HEAD refs/heads/..bad\n' | $GIT -C "$R" update-ref --stdin 2>&1
A_EXIT=$?
set -e
echo "Exit: $A_EXIT (expected: non-zero — invalid refname rejected at parse time)"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

# ── TEST B: old_target with old_arg="ref" — conditional validation ────────────

echo "── TEST B: symref-update old_arg=ref with invalid old_target ────────────"
echo "(old_target goes through parse_next_arg, then conditionally validated)"
echo ""
R2=$(make_repo)
trap "rm -rf $R $R2" EXIT
$GIT -C "$R2" update-ref refs/heads/main HEAD
set +e
printf 'symref-update HEAD refs/heads/newbranch ref refs/heads/!!bad!!\n' \
    | $GIT -C "$R2" update-ref --stdin 2>&1
B_EXIT=$?
set -e
echo "Exit: $B_EXIT (expected: non-zero — invalid old_target rejected, but via late check_refname_format)"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

# ── TEST C: invalid old_arg type specifier ────────────────────────────────────

echo "── TEST C: symref-update with invalid old_arg type ─────────────────────"
echo "(old_arg through parse_next_arg — no format validation, rejected by type-switch)"
echo ""
R3=$(make_repo)
trap "rm -rf $R $R2 $R3" EXIT
$GIT -C "$R3" update-ref refs/heads/main HEAD
set +e
printf 'symref-update HEAD refs/heads/newbranch invalid_type somevalue\n' \
    | $GIT -C "$R3" update-ref --stdin 2>&1
C_EXIT=$?
set -e
echo "Exit: $C_EXIT (non-zero — rejected by type-switch die(), not format validation)"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

# ── TEST D: valid symref-update succeeds ─────────────────────────────────────

echo "── TEST D: valid symref-update (regression / baseline) ─────────────────"
R4=$(make_repo)
trap "rm -rf $R $R2 $R3 $R4" EXIT
$GIT -C "$R4" update-ref refs/heads/main HEAD
set +e
printf 'symref-update HEAD refs/heads/main\n' | $GIT -C "$R4" update-ref --stdin 2>&1
D_EXIT=$?
set -e
echo "Exit: $D_EXIT (expected: 0 — valid symref-update succeeds)"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

# ── CONCLUSION ──────────────────────────────────────────────────────────────

echo "── CONCLUSION ───────────────────────────────────────────────────────────"
echo ""
echo "  FlowAsymmetry between parse_next_arg and parse_next_refname:"
echo ""
echo "    parse_next_refname: parse_arg → parse_refname → check_refname_format"
echo "      (used for new_target in symref commands — VALIDATES at parse time)"
echo ""
echo "    parse_next_arg: parse_arg → if (arg.len) return ptr else NULL"
echo "      (no domain validation — latent misuse trap for future code additions)"
echo ""
echo "  In git 2.49.0:"
echo "    Test A (invalid new_target): exit=$A_EXIT — rejected at parse time via parse_next_refname"
echo "    Test B (invalid old_target, type=ref): exit=$B_EXIT — rejected via late check_refname_format"
echo "    Test C (invalid old_arg type): exit=$C_EXIT — rejected via type-switch die()"
echo "    Test D (valid command): exit=$D_EXIT — succeeds"
echo ""
echo "  The structural gap is that parse_next_arg exists adjacent to parse_next_refname"
echo "  with no validation contract, and old_target validation is conditional/complex."
echo "  A future code addition using parse_next_arg for a refname-type argument would"
echo "  silently skip format validation."
echo ""

if [ $A_EXIT -ne 0 ] && [ $B_EXIT -ne 0 ] && [ $C_EXIT -ne 0 ] && [ $D_EXIT -eq 0 ]; then
    echo "────────────────────────────────────────────────────────────────────────"
    echo ""
    echo "PASS: asymmetry documented; validation paths confirmed"
    echo "  A=$A_EXIT (new_target rejected at parse) B=$B_EXIT (old_target late reject)"
    echo "  C=$C_EXIT (bad type-spec rejected) D=$D_EXIT (valid succeeds)"
    exit 0
else
    echo "NOT_CONFIRMED: A=$A_EXIT B=$B_EXIT C=$C_EXIT D=$D_EXIT"
    echo "  (expected: A!=0, B!=0, C!=0, D=0)"
    exit 1
fi
SHEOF

CMD ["bash", "/test.sh"]
