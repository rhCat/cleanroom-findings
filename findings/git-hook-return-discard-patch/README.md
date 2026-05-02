# Patch Cleanroom: git-hook-return-discard fix

**Type**: Patch verification  
**Bug cleanroom**: `findings/git-hook-return-discard/`

---

## What This Cleanroom Proves

This cleanroom verifies that the proposed one-line fix to `refs.c` works correctly:

1. **Patch applies** to git 2.43.7 source without conflicts
2. **Patched git compiles** and installs successfully
3. **Warning is emitted** when the reference-transaction hook fails on the `committed` phase
4. **No regression**: `git push` still exits 0 (hook failure on `committed` is non-fatal
   by design — the ref write already succeeded)

---

## The Patch

```c
/* refs.c — in ref_transaction_commit() */

/* Before */
run_transaction_hook(transaction, "committed");

/* After */
if (run_transaction_hook(transaction, "committed"))
    warning("reference-transaction hook failed for committed phase");
```

This is the minimal fix. A stricter fix would surface the failure to the caller,
but that would require changing the `ref_transaction_commit` return contract and
could break callers that don't check the return value. The warning approach is
consistent with git's existing treatment of non-fatal hook failures.

---

## How to Verify

```sh
cd findings/git-hook-return-discard-patch
docker build -t git-hook-return-discard-patch . && docker run --rm git-hook-return-discard-patch
```

Build time ~15s (compiles git 2.43.7 from source).

**Expected output:**
```
PASS (PATCHED): git push exited 0 and emitted warning about hook failure -- patch verified
```

The key line in the push output:
```
warning: reference-transaction hook failed for committed phase
```

---

## Relationship to Bug Cleanroom

The bug cleanroom (`findings/git-hook-return-discard/`) demonstrates the existing
silent-failure behavior using stock unmodified git and git's public hook interface
(no source modification required). That cleanroom is independent of this patch
cleanroom.

This cleanroom exists solely to verify that the proposed patch changes the behavior
in the intended direction without regressions.
