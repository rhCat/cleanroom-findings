# Patch Cleanroom: git-merge-ort rename-pipeline-discard fix

**Type**: Patch verification  
**Bug cleanroom**: `findings/git-merge-ort-rename-pipeline-discard/`

---

## What This Cleanroom Proves

This cleanroom verifies that the proposed error-propagation patch to `merge-ort.c`
works correctly:

1. **Patch applies** to git 2.43.7 source without conflicts
2. **Patched git compiles** and installs successfully
3. **Normal merges still work** — the rename/rename conflict is still detected correctly (regression check)
4. **Error path is wired** — when `detect_regular_renames` returns -1,
   `detect_and_process_renames` propagates it as `clean = -1`, causing the merge
   to abort with exit 2 rather than silently committing a wrong tree

---

## Note on Test Methodology

The patch error path is verified using `GIT_TEST_RENAME_DISCARD=1`, a test hook
added by the patch itself (analogous to git's internal `GIT_TEST_*` variables used
throughout `t/`). This hook exercises the `-1` return path that would be triggered
in production by a failable `diffcore_rename_extended`.

**This is patch testing, not a wild bug reproducer.** The bug cleanroom
(`findings/git-merge-ort-rename-pipeline-discard/`) separately documents
why the bug has no wild reproducer.

---

## How to Verify

```sh
cd findings/git-merge-ort-rename-pipeline-discard-patch
docker build -t git-merge-ort-patch . && docker run --rm git-merge-ort-patch
```

Build time ~15s (compiles git 2.43.7 from source).

**Expected output:**
```
── TEST A: Normal merge — regression check
$ git merge side1
CONFLICT (rename/rename): foo.c renamed to baz.c in HEAD and to bar.c in side1.
Exit: 1   ← conflict still detected, no regression

── TEST B: Error path — GIT_TEST_RENAME_DISCARD=1
$ GIT_TEST_RENAME_DISCARD=1 git merge side1
error: rename detection failed; aborting merge to prevent tree corruption
Exit: 2   ← clean abort, no wrong tree committed

PASS (PATCHED): rename detection failure propagates as merge abort
```

---

## The Patch (Summary)

```c
/* merge-ort.c — detect_regular_renames() */
/* Add -1 return path for future error signaling from diffcore_rename_extended */
if (getenv("GIT_TEST_RENAME_DISCARD")) {
    renames->pairs[side_index].nr = 0;
    renames->pairs[side_index].queue = NULL;
    return -1;
}

/* merge-ort.c — detect_and_process_renames() */
/* Before: |= cannot detect -1 */
detection_run |= detect_regular_renames(opt, MERGE_SIDE1);
detection_run |= detect_regular_renames(opt, MERGE_SIDE2);

/* After: check for -1, abort before processing empty pairs */
if (detect_regular_renames(opt, MERGE_SIDE1) < 0 ||
    detect_regular_renames(opt, MERGE_SIDE2) < 0) {
    error(_("rename detection failed; aborting merge to prevent tree corruption"));
    clean = -1;
    goto cleanup;
}
detection_run = 1;
```

With `clean = -1`:
- `result->clean = -1` in `merge_ort_nonrecursive_internal`
- `builtin/merge.c:837`: `if (clean < 0) { rollback_lock_file(&lock); return 2; }`
- Merge aborts cleanly. No wrong tree committed.

---

## Limitations

The patch wires the error path but `diffcore_rename_extended` itself does not yet
return errors. A companion patch to `diffcore.c` / `diffcore-rename.c` is needed
to complete the fix. This patch is preparatory: it ensures the propagation path
exists so that when `diffcore_rename_extended` gains error signaling, it will work
correctly end-to-end.
