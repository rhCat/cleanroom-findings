# Source Citations — merge-ort rename pipeline

Git version: HEAD (post-v2.49.0, `e895506107`)  
Investigation version: v2.49.0 (`7d5bb9c6`) — line numbers may differ by ±10

---

## C1 Primary Finding — `detect_and_process_renames`

### Call site 1: `detect_regular_renames` for SIDE1 (no -1 path)
**File**: `merge-ort.c`  
**Approx line**: 3564 (v2.49.0)  
**Pattern**: `detection_run |= detect_regular_renames(opt, MERGE_SIDE1);`

```c
	trace2_region_enter("merge", "regular renames", opt->repo);
	detection_run |= detect_regular_renames(opt, MERGE_SIDE1);
	detection_run |= detect_regular_renames(opt, MERGE_SIDE2);
```

`detection_run` accumulates boolean "did detection run" (0 or 1). If
`detect_regular_renames` fails internally, it returns 1 (as if it ran)
but leaves `renames->pairs[side_index]` in an empty/undefined state.
There is no -1 return path for internal errors.

### Call site 2: `detect_regular_renames` for SIDE2 (same pattern)
**Approx line**: 3565

### Call sites 3-4: `collect_renames` — SIDE1 and SIDE2
**Approx lines**: 3612, 3616  
**Pattern**: `clean &= collect_renames(opt, &combined, MERGE_SIDE1, ...);`

`clean &=` correctly propagates "has conflicts" (0) but `collect_renames`
returns 0 only for directory rename CONFLICTS, not for internal errors.
If `detect_regular_renames` silently failed, `side_pairs->nr == 0` and
`collect_renames` loops over nothing, returning `clean = 1`.

### Call site 5: `process_renames`
**Approx line**: 3626  
**Pattern**: `clean &= process_renames(opt, &combined);`

If `combined` is empty (due to upstream silent failure), `process_renames`
processes nothing and returns `clean = 1`. No renames are recorded in
`opt->priv->paths`.

---

## `detect_regular_renames` function — missing error path
**File**: `merge-ort.c`  
**Approx line**: 3423–3484  

```c
static int detect_regular_renames(struct merge_options *opt,
				  unsigned side_index)
{
	...
	/* NOTE: diffcore_rename_extended is called with no error check */
	diffcore_rename_extended(&diff_opts,
				 &opt->priv->pool,
				 &renames->relevant_sources[side_index],
				 ...);
	...
	renames->pairs[side_index] = diff_queued_diff;
	...
	return 1;  /* ← only return for "ran"; no -1 for "ran but failed" */
}
```

`diffcore_rename_extended` has no error return in the current API. If it
encounters an error internally (OOM, signal, missing object in partial
clone), the failure is undetectable by the caller.

---

## C2 Secondary — `collect_merge_info_callback`
**File**: `merge-ort.c`  
**Approx line**: 1494  

```c
/* traverse_trees_wrapper return value discarded */
traverse_trees_wrapper(...);
```

If `traverse_trees_wrapper` fails for a path, that path is silently
absent from `opt->priv->paths`. The merge tree will be missing that
file with no indication of the omission.

---

## C3 Secondary — `merge_ort_nonrecursive_internal`
**File**: `merge-ort.c`  
**Approx lines**: 5248, 5250  

```c
if (opt->subtree_shift) {
	side2 = shift_tree_object(opt->repo, side1, side2, opt->subtree_shift);
	merge_base = shift_tree_object(opt->repo, side1, merge_base, opt->subtree_shift);
}
```

Neither `shift_tree_object` result is checked for NULL. A NULL `side2`
or `merge_base` passed to `collect_merge_info` invokes UB or an ODB
lookup with a zero OID (empty tree).

---

## `builtin/merge.c` — `clean < 0` handler
**Approx line**: 837  

```c
if (clean < 0) {
	rollback_lock_file(&lock);
	return 2;
}
```

If `result->clean = -1`, the merge command rolls back and exits 2.
This is the mechanism the patch exploits for safe abort.
