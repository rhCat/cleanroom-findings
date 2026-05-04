# Patch Cleanroom: git-merge-ort-make-virtual-commit-error-discard

**Bug cleanroom**: `findings/git-merge-ort-make-virtual-commit-error-discard/`  
**Type**: Patch cleanroom — adds NULL guards to `make_virtual_commit` call sites  
**Status**: VERIFIED  
**Git version patched**: v2.43.7 (Alpine 3.19)

---

## What the Patch Does

Adds NULL guards at both `make_virtual_commit` call sites in `merge_ort_internal`:

1. **Initial ancestor** (~L5335): `if (!merged_merge_bases) die(...)` after the
   empty-tree ancestor construction.
2. **Loop body** (~L5374): `if (!merged_merge_bases) die(...)` before the
   `commit_list_insert` dereferences.

The fix uses `die()` — consistent with the existing allocator behavior (xcalloc
already calls die() on OOM) and appropriate since no recovery is possible in this
context.

---

## Test Strategy

The test uses `GIT_TEST_MAKE_VIRTUAL_COMMIT_FAIL=1`, a test hook injected by the
patch itself (analogous to git's own `GIT_TEST_*` variables). The hook makes
`make_virtual_commit` return NULL on its second call — exercising the loop body
path that would crash without the guard.

**Test A** (regression): normal criss-cross merge with no hook → verify merge
completes (with conflict) and both renames are tracked.

**Test B** (NULL guard): `GIT_TEST_MAKE_VIRTUAL_COMMIT_FAIL=1` → verify
`die()` fires with the expected message rather than SIGSEGV.
