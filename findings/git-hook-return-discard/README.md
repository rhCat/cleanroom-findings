# Finding: git hook-return-discard (reference-transaction hook silent failure)

**Severity**: Medium-High  
**Component**: `refs.c` — reference transaction lifecycle  
**Affected functions**: `ref_transaction_commit`, `ref_transaction_abort`  
**Git version tested**: v2.49.0 (7d5bb9c6)  
**Detector**: alembic FlowAsymmetry + ErrorPropagation  

---

## Structural Description

Git's reference-transaction hook mechanism (`$GIT_DIR/hooks/reference-transaction`)
is called at four lifecycle phases: `preparing`, `prepared`, `committed`, `aborted`.

The hook is invoked via `run_transaction_hook(transaction, phase_name)` which returns
an integer error code. The calling contract is **asymmetric**:

| Phase | Caller | Return checked? | On failure |
|-------|--------|-----------------|------------|
| `preparing` | `ref_transaction_prepare` | **yes** | die() |
| `prepared` | `ref_transaction_prepare` | **yes** | die() |
| `committed` | `ref_transaction_commit` | **NO** | silently ignored |
| `aborted` | `ref_transaction_abort` | **NO** | silently ignored |

This asymmetry means:

1. A hook that fails before refs are locked will abort the transaction (correct).
2. A hook that fails *after* refs are committed returns success to the caller —
   the ref update succeeded, but all hook side effects are silently lost.

## Silent Failure Mode

```
caller (e.g. git push) → ref_transaction_commit() → backend writes refs → OK
                                                   → run_transaction_hook("committed") → FAIL
                                                   → return 0  ← caller sees SUCCESS
```

The hook's side effects (e.g. marking a PR as merged, posting a webhook, updating
a tracking system) are lost. Git returns 0. No log entry. No retry. The caller
has no mechanism to detect this.

## Why It Matches "PR Side-Effect Lost"

Any CI/CD system or PR tracker that uses the `reference-transaction` hook to
observe when branches are updated will silently miss updates if the hook fails
post-commit. Symptoms:
- `git push` reports success
- Branch is updated on the server
- PR tracking system shows the branch as unchanged / PR as still open
- No error in git output or server logs (unless hook stderr is captured separately)

This is consistent with the "PR disappear" symptom class: the push succeeds,
the ref is written, but downstream state (PR status, CI trigger, sync hook)
is never updated.

## Related Finding

`ref_transaction_prepare` also discards the return value of `ref_transaction_abort`
at lines 2666 and 2676 (failure cleanup path). If the abort itself fails, the
transaction is left in an intermediate state with no clean recovery path.

---

## Reproducible Docker Cleanroom

**Bug Dockerfile** (stock unmodified git — no source modification):

```sh
cd findings/git-hook-return-discard
docker build -t git-hook-return-discard . && docker run --rm git-hook-return-discard
```

**Expected output (git 2.43.7 / Alpine 3.19):**
```
CONTRADICTION: git push exited 0 and ref was written, but reference-transaction
hook failed on 'committed' phase -- side-effects silently discarded
(refs.c:2736 run_transaction_hook return unchecked)
```

**Image size**: ~24 MiB  |  **Build time**: ~2s

**Patch cleanroom** (separate artifact — verifies the fix, not the bug):  
`findings/git-hook-return-discard-patch/`
