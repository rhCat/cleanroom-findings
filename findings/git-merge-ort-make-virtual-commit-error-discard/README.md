# Finding: git-merge-ort-make-virtual-commit-error-discard

**Severity**: Medium (NULL deref under allocator failure in recursive merge base reduction)  
**Component**: `merge-ort.c` — `merge_ort_internal` recursive merge base loop  
**Affected lines**: ~5335 (initial ancestor), ~5374 (loop body), ~5377/5384 (downstream deref)  
**Git version tested**: v2.43.7 (Alpine 3.19 package baseline)  
**Detector**: alembic FlowAsymmetry + ErrorPropagation (Phase 6.1 C unified-vocab)

---

## Structural Description

`merge_ort_internal` handles the recursive merge-base reduction path: when multiple
merge bases exist, it merges them pairwise to produce a virtual merge base. It calls
`make_virtual_commit` at two points:

1. **L5335** — constructing the initial empty-tree ancestor when no real merge base exists:
   ```c
   merged_merge_bases = make_virtual_commit(opt->repo, tree, "ancestor");
   ```
2. **L5374** — updating `merged_merge_bases` after each iteration of the reduction loop:
   ```c
   merged_merge_bases = make_virtual_commit(opt->repo, result->tree, "merged tree");
   commit_list_insert(prev, &merged_merge_bases->parents);       /* ← L5377 deref */
   commit_list_insert(next, &merged_merge_bases->parents->next); /* ← L5384 deref */
   ```

Neither call checks for a NULL return. If `make_virtual_commit` returns NULL,
the immediately following `->parents` dereferences crash with SIGSEGV.

### Callgraph to Allocator

```
make_virtual_commit(repo, tree, name)
  → alloc_commit_node(repo)         [commit.c]
      → mem_pool_calloc(&pool, 1, size)
          → xcalloc / xmalloc      [wrapper with die() on OOM in most builds]
```

In default builds, `xcalloc` calls `die()` on OOM rather than returning NULL,
so `alloc_commit_node` cannot currently return NULL. The NULL deref path is
therefore a **latent structural gap** — it is reachable code with no current
production trigger.

### Why It Is Still a Finding

- `make_virtual_commit` has no documented guarantee that it never returns NULL.
  Its signature is `struct commit *make_virtual_commit(struct repository *, struct tree *, const char *)` — a nullable pointer return.
- The allocator wrapper (`xmalloc`) has historically been replaced or wrapped in
  embedded/constrained builds (e.g., `NO_MMAP`, custom pool allocators).
- Any future refactor that changes `alloc_commit_node` to return NULL on failure
  (e.g., for non-fatal OOM handling) would immediately produce exploitable NULL
  derefs in the merge base loop.
- The sibling call at L5348 (assigning the initial `merged_merge_bases`) passes
  its result directly to `commit_list_insert` without a NULL check.

---

## Silent Failure Mode

```
git merge --strategy=ort <multiple_merge_bases>
  → merge_ort_nonrecursive_internal
      → detect merge base count > 1
      → merge_ort_internal (recursive)
          → make_virtual_commit(...)   [FAILURE — returns NULL]
          → commit_list_insert(prev, &NULL->parents)
              → SIGSEGV
```

The crash surface is limited to the recursive merge base path, which requires
at least two common ancestors between the branches being merged (a "criss-cross"
merge topology). This path is exercised by, e.g., `git merge-recursive` test
fixtures with synthetic diamond histories.

---

## No Wild Reproducer

This finding records a **structural gap**. The current allocator chain
(`make_virtual_commit → alloc_commit_node → mem_pool_calloc`) does not return
NULL in standard builds — it calls `die()` instead. No production condition
currently reaches the NULL deref.

The vulnerability is the **absence of a NULL guard** at the two call sites. A
reviewer can verify the structural gap by reading `references/git-source-snippet.c`
and the source citations in `SOURCES.md`.

This cleanroom is documented for upstream **defensive-coding review**.

---

## Proposed Fix Shape

```c
/* In merge_ort_internal, initial ancestor path: */
merged_merge_bases = make_virtual_commit(opt->repo, tree, "ancestor");
if (!merged_merge_bases)
    die(_("out of memory: make_virtual_commit failed"));

/* In merge_ort_internal, reduction loop body: */
merged_merge_bases = make_virtual_commit(opt->repo, result->tree, "merged tree");
if (!merged_merge_bases)
    die(_("out of memory: make_virtual_commit failed"));
commit_list_insert(prev, &merged_merge_bases->parents);
commit_list_insert(next, &merged_merge_bases->parents->next);
```

Since `make_virtual_commit` is called from a context where recovery is not
meaningful, `die()` is the appropriate response — consistent with how
`xcalloc` already handles OOM in standard builds.

**Patch cleanroom** (separate artifact):
`findings/git-merge-ort-make-virtual-commit-error-discard-patch/`
