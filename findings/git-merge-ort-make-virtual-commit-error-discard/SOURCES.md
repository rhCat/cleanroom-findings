# Source Citations — merge-ort make_virtual_commit NULL deref

Git version: HEAD (post-v2.49.0, `e895506107`)  
Investigation version: v2.49.0 (`7d5bb9c6`) — line numbers may differ by ±10

---

## Primary Finding — `merge_ort_internal`

### Call site 1: initial empty-tree ancestor (no NULL check)
**File**: `merge-ort.c`  
**Approx line**: 5335 (v2.49.0)  
**Pattern**: `merged_merge_bases = make_virtual_commit(opt->repo, tree, "ancestor");`

```c
struct tree *tree;
tree = lookup_tree(opt->repo, opt->repo->hash_algo->empty_tree);
merged_merge_bases = make_virtual_commit(opt->repo, tree, "ancestor");
ancestor_name = "empty tree";
/* NO NULL CHECK — merged_merge_bases passed to commit_list_insert below */
```

### Call site 2: reduction loop body (no NULL check, immediate deref)
**File**: `merge-ort.c`  
**Approx line**: 5374 (v2.49.0)  
**Pattern**: `merged_merge_bases = make_virtual_commit(...); commit_list_insert(prev, &merged_merge_bases->parents);`

```c
merged_merge_bases = make_virtual_commit(opt->repo, result->tree,
                                          "merged tree");
/* ↓ NULL DEREF if make_virtual_commit returns NULL */
commit_list_insert(prev, &merged_merge_bases->parents);
commit_list_insert(next, &merged_merge_bases->parents->next);
```

---

## `make_virtual_commit` definition
**File**: `commit.c`  
**Pattern**: calls `alloc_commit_node` → `mem_pool_calloc`

```c
struct commit *make_virtual_commit(struct repository *repo,
                                   struct tree *tree,
                                   const char *comment)
{
    struct commit *commit = alloc_commit_node(repo);
    /* alloc_commit_node → mem_pool_calloc → xcalloc → die() on OOM */
    set_merge_remote_desc(commit, comment, (struct object *)commit);
    commit->maybe_tree = tree;
    commit->object.parsed = 1;
    return commit;
}
```

`alloc_commit_node` currently cannot return NULL because `xcalloc` calls `die()`
on OOM before returning a NULL pointer. The NULL check gap is latent.

---

## Downstream dereference — `commit_list_insert`
**File**: `commit.c` (inline/header)  
**Pattern**: `entry->next = list_head; *list = entry;`

If `merged_merge_bases` is NULL, `&merged_merge_bases->parents` is a NULL
pointer dereference at the struct offset of `parents` — SIGSEGV in the
merge reduction loop.

---

## Contrast: other callers that DO check
`builtin/merge.c` and `sequencer.c` do not call `make_virtual_commit` directly.
The function is only called from `merge_ort_internal`. The absence of a guard
is therefore contained to this call site.
