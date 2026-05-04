# Finding: git-update-ref-parse-arg-inconsistency

**Severity**: Low (validation depth inconsistency; structural latent misuse trap)  
**Component**: `builtin/update-ref.c` — `parse_next_arg` vs `parse_next_refname`  
**Affected function**: `parse_next_arg` (~L106 in v2.49.0)  
**Git version tested**: v2.49.0 (`7d5bb9c6`)  
**Note**: symref commands and `parse_next_arg` not present in v2.43.7; added in v2.49.0  
**Detector**: alembic FlowAsymmetry (Phase 6.1 C unified-vocab)

---

## Structural Description

`builtin/update-ref.c` (v2.49.0) has two argument-parsing helpers for symref
commands that differ significantly in validation behavior:

| Helper | Validates | Used for |
|--------|-----------|----------|
| `parse_next_refname` (~L82) | `check_refname_format` via `parse_refname` | `<new-target>` in all symref commands |
| `parse_next_arg` (~L106) | None (only non-NULL check) | `old_arg` type specifier and `old_target` in `symref-update` |

`parse_next_refname` correctly validates refnames at parse time. `parse_next_arg`
returns any non-empty string without format checking.

### `symref-update` argument flow

```c
/* parse_cmd_symref_update: */
new_target = parse_next_refname(&next);   /* ← VALIDATED at parse time */

old_arg = parse_next_arg(&next);          /* ← no validation */
if (old_arg) {
    old_target = parse_next_arg(&next);   /* ← unvalidated at parse time */
    if (!strcmp(old_arg, "oid")) {
        repo_get_oid(...);                /* ← late OID validation */
    } else if (!strcmp(old_arg, "ref")) {
        check_refname_format(old_target); /* ← late refname validation */
    } else {
        die(...);
    }
}
```

`old_target` validation is **conditional and deferred** — it happens only when
`old_arg == "ref"` and is placed after a non-trivial type-switch. The validation
for `old_arg` itself (the type specifier "oid"/"ref") is handled only by the
type-switch `die()` fallthrough, not by `parse_next_arg`.

---

## FlowAsymmetry Evidence

`parse_next_refname` and `parse_next_arg` have similar signatures and serve
adjacent roles in the same dispatch functions:

```
parse_next_refname: skip_delim → parse_refname() → check_refname_format → die on invalid
parse_next_arg:     skip_delim → parse_arg()     → (no domain validation)
```

The asymmetry is a **latent misuse trap**: a future developer adding a new symref
command could reach for `parse_next_arg` instead of `parse_next_refname` for a
refname-type argument. The code would compile correctly, and the error would only
surface at transaction-commit time with a less clear error message.

---

## Observed Behavior (v2.49.0)

```bash
# Invalid new_target — rejected early by parse_next_refname
printf 'symref-update HEAD refs/heads/..bad\n' | git update-ref --stdin
# → fatal: invalid ref format: refs/heads/..bad (exit 128)

# Invalid old_target with type=ref — rejected by late check_refname_format
printf 'symref-update HEAD refs/heads/main ref refs/heads/..bad\n' \
    | git update-ref --stdin
# → fatal: symref-update HEAD: invalid ref: refs/heads/..bad (exit 128)

# Invalid old_arg type — rejected by type-switch die()
printf 'symref-update HEAD refs/heads/main invalid-type somevalue\n' \
    | git update-ref --stdin
# → fatal: symref-update HEAD: invalid arg 'invalid-type' for old value (exit 128)
```

All error paths reject correctly. The finding is **structural**: the complexity
and conditionality of `old_target` validation, and the existence of `parse_next_arg`
as an unvalidated helper, are latent risks for future code additions.

---

## No Wild Bug in v2.49.0

The current implementation in git 2.49.0 is functionally correct: `new_target`
uses `parse_next_refname` (validated), and `old_target` is validated conditionally
but completely. The finding is a **structural observation** about code complexity
and the latent misuse risk from `parse_next_arg`.

The FlowAsymmetry detector correctly identified that `parse_next_arg` lacks domain
validation while its sibling `parse_next_refname` does not — the signal is valid
even though the current call sites are correctly wired.

**Documentation cleanroom** (no patch needed): the behavior is documented in the
patch cleanroom's test output, which verifies that all rejection paths work correctly.

**Patch cleanroom**: `findings/git-update-ref-parse-arg-inconsistency-patch/`
