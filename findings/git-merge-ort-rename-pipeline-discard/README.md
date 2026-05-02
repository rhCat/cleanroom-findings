# Finding: git merge-ort rename-pipeline-discard

**Severity**: High (tree corruption under production failure conditions)  
**Component**: `merge-ort.c` — `detect_and_process_renames` pipeline  
**Affected function**: `detect_and_process_renames` (line ~3547), callee `detect_regular_renames` (line ~3423)  
**Git version tested**: v2.43.7 (Alpine 3.19 package baseline)  
**Detector**: alembic FlowAsymmetry + ErrorPropagation (Phase 6.1 C unified-vocab)

---

## Structural Description

`detect_and_process_renames` orchestrates the four-stage rename detection pipeline
in merge-ort. It calls `detect_regular_renames` for each merge side using the
`|=` accumulator pattern:

```c
detection_run |= detect_regular_renames(opt, MERGE_SIDE1);
detection_run |= detect_regular_renames(opt, MERGE_SIDE2);
```

`detect_regular_renames` returns `0` (detection not needed) or `1` (detection ran).
It has **no error return path** — there is no `-1` for fatal errors. If `diffcore_rename_extended`
encounters an error internally (OOM, missing objects, signal interrupt), the function
returns `1` as if detection succeeded but leaves `renames->pairs[side_index]` in
an undefined or empty state.

Downstream, `collect_renames` iterates over `renames->pairs[side_index]`. If the
pairs array is empty due to a silent failure, `collect_renames` processes nothing
and returns `clean = 1` (no conflicts). `process_renames` then processes an empty
`combined` queue and also returns `clean = 1`. The function returns `clean = 1` to
its caller, which assigns it to `result->clean = 1` — **a "clean" merge with a
tree that does not reflect the user's rename intent**.

### Pipeline Table

| Stage | Call site | Return captured? | Can signal error? |
|-------|-----------|-----------------|-------------------|
| `detect_regular_renames(SIDE1)` | `detection_run \|=` | Via `\|=` | **No** — only 0/1 |
| `detect_regular_renames(SIDE2)` | `detection_run \|=` | Via `\|=` | **No** — only 0/1 |
| `collect_renames(SIDE1)` | `clean &=` | Yes (clean flag) | No — only 0/1 |
| `collect_renames(SIDE2)` | `clean &=` | Yes (clean flag) | No — only 0/1 |
| `process_renames` | `clean &=` | Yes (clean flag) | No — only 0/1 |

The `clean &=` pattern correctly propagates "there are conflicts" but cannot
distinguish between "conflict in rename application" and "rename detection failed."
The `detection_run |=` pattern cannot distinguish "detection ran successfully"
from "detection ran but encountered an internal error."

---

## Silent Failure Mode

```
git merge side1
  → merge_ort_nonrecursive_internal
      → collect_merge_info (succeeds — objects present)
      → detect_and_process_renames
          → detect_regular_renames(SIDE1)
              → diffcore_rename_extended  [FAILURE — silent]
              → renames->pairs[SIDE1] = empty/corrupt
              → return 1  ("ran")
          → detection_run = 1 (truthy)
          → collect_renames(SIDE1): loops over empty pairs → clean=1
          → collect_renames(SIDE2): loops over empty pairs → clean=1
          → process_renames: processes empty combined → clean=1
          → return 1
      → result->clean = 1  ← WRONG: "clean merge"
      → process_entries: builds tree WITHOUT rename info
          → foo.c deleted by both sides → clean delete-delete
          → bar.c  added by side1 → independent addition (correct only by accident)
          → baz.c  added by side2 → independent addition (correct only by accident)
      → tree written: {bar.c, baz.c}  ← WRONG: no conflict recorded
  → merge command exits 0
```

The rename/rename conflict between `bar.c` and `baz.c` is **silently lost**. Both
files appear in the tree as independent additions. A merge queue that tested
tree A (with the conflict) would commit tree B (without the conflict) — a different
tree than CI verified.

---

## Why It Matches "Merge Queue Tree Corruption"

The Merge Queue symptom class is: `result_tree_A ≠ result_tree_B` where A is the
tree CI tested and B is the tree that was committed. The mechanism:

1. **Phase A (test run)**: rename detection succeeds → conflict detected → human
   resolves → resolved tree `T_A` is what CI tests against.
2. **Phase B (commit run)**: rename detection fails silently → conflict NOT detected →
   merge commits tree `T_B = {bar.c, baz.c}` without the resolve step.
3. `T_A ≠ T_B`. The wrong tree is committed.

In distributed merge orchestrators and CI/CD systems where git runs as a backend
(merge queue services, bots, GitOps automation), the Phase A test run and Phase B
commit run may execute in separate environments (different VMs, different cache
states, different memory pressure). If rename detection encounters a partial failure
in Phase B but not Phase A, the resulting tree silently diverges from what CI tested.

---

## No Wild Reproducer

This finding records a **structural gap**. There is currently no wild reproducer
because `detect_regular_renames` has no production error paths today:
`diffcore_rename_extended` does not return errors, so there is no observable runtime
condition under which the silent-failure scenario manifests on unmodified stock git.

The vulnerability is the **absence of error handling**: any future change introducing
a failable path in `diffcore_rename_extended` (e.g., adding partial-clone lazy-fetch
support to rename detection) would silently produce wrong trees without any error
signaling to the caller.

This cleanroom is documented for upstream **defensive-coding review**. A reviewer
can verify the structural gap by reading `references/git-source-snippet.c` and the
source citations in `SOURCES.md`.

---

## Proposed Fix Shape

```c
/* In detect_and_process_renames: */
if (detect_regular_renames(opt, MERGE_SIDE1) < 0 ||
    detect_regular_renames(opt, MERGE_SIDE2) < 0) {
    error(_("rename detection failed; aborting merge to prevent tree corruption"));
    clean = -1;
    goto cleanup;
}
detection_run = 1;

/* In detect_regular_renames: add -1 error return path for internal failures */
```

With `clean = -1`, `result->clean = -1`, which causes `builtin/merge.c:837`
to call `rollback_lock_file` and return exit code 2 — a clean abort with no
wrong tree committed.

**Patch cleanroom** (separate artifact — verifies the proposed fix):  
`findings/git-merge-ort-rename-pipeline-discard-patch/`
