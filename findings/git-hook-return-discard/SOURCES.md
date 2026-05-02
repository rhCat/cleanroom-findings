# Sources and Citations

## Primary Code Locations

### P1 — `ref_transaction_commit` (refs.c:2736)
```
File:     refs.c
Line:     2736 (git v2.49.0 / commit 7d5bb9c6)
Function: ref_transaction_commit
Symbol:   run_transaction_hook(transaction, "committed")
Issue:    Return value of run_transaction_hook() is discarded.
          The commit returns ret (backend result) regardless of hook outcome.
```

```c
ret = refs->be->transaction_finish(refs, transaction, err);
if (!ret && !(transaction->flags & REF_TRANSACTION_FLAG_INITIAL))
    run_transaction_hook(transaction, "committed");   // <-- return discarded
return ret;
```

### P2 — `ref_transaction_abort` (refs.c:2704)
```
File:     refs.c
Line:     2704 (git v2.49.0 / commit 7d5bb9c6)
Function: ref_transaction_abort
Symbol:   run_transaction_hook(transaction, "aborted")
Issue:    Return value of run_transaction_hook() is discarded.
```

```c
run_transaction_hook(transaction, "aborted");   // <-- return discarded
ref_transaction_free(transaction);
return ret;
```

### P3 (secondary) — `ref_transaction_prepare` cleanup paths (refs.c:2666, 2676)
```
File:     refs.c
Lines:    2666, 2676
Function: ref_transaction_prepare
Symbol:   ref_transaction_abort(transaction, err)   (called on prepare failure)
Issue:    Error code from abort is discarded on both failure exit paths.
          If the cleanup abort fails, transaction is left in partial state.
```

## Contrast — Checked Call Sites (same function)
```
File:     refs.c
Lines:    ~2664, ~2679
Function: ref_transaction_prepare
Symbol:   run_transaction_hook(transaction, "preparing") / "prepared"
Pattern:  ret = run_transaction_hook(...); if (ret) { abort + die }
```
This is the correct pattern that P1/P2 should follow (with warning() instead
of die() for the commit/abort phases since they cannot undo the ref write).

## Commit References
- git v2.49.0: commit `7d5bb9c6` (checkout tag v2.49.0)
- Reference-transaction hook introduced: git commit `9b6b57e5` (2020, "hooks: reference-transaction")
- The asymmetric check pattern appears to date from the original introduction.

## Supporting Documentation
- `Documentation/githooks.txt` — reference-transaction hook specification
- `Documentation/git-hook.txt` — hook infrastructure
