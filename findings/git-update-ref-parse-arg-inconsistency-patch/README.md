# Patch Cleanroom: git-update-ref-parse-arg-inconsistency

**Bug cleanroom**: `findings/git-update-ref-parse-arg-inconsistency/`  
**Type**: Patch cleanroom — adds refname validation to `parse_next_arg`  
**Status**: VERIFIED  
**Git version patched**: v2.43.7 (Alpine 3.19)

---

## What the Patch Does

Introduces `parse_next_symref_target` — a wrapper around `parse_next_arg`
that adds `check_refname_format` validation. Updates `symref-update`,
`symref-create`, `symref-delete`, and `symref-verify` to use the new helper
for their target arguments.

Before the patch, `parse_next_arg` accepted any non-empty string for symref
target values without checking refname format. After the patch, invalid
refnames are rejected at parse time with a clear, early error message.

---

## Test Strategy

**Test A** (regression): valid `symref-update` command → should succeed.  
**Test B** (wild reproducer): stock git behavior with invalid target → shows
late or absent error.  
**Test C** (patch behavior): patched git with invalid target → early rejection
with clear `invalid ref format` message.  
**Test D** (comparison): `update` with bad OID on stock git → always rejected
early (shows the asymmetry that the patch closes).
