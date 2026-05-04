# Reproducer Attempt — git-update-ref-parse-arg-inconsistency

## Summary

`parse_next_arg` accepts any non-empty string for symref target arguments.
The question is whether this acceptance propagates all the way to writing an
invalid symref target, or whether the ref transaction layer catches it later.

## Test Cases

### Test 1: `update` with bad OID — expected early rejection

```bash
printf 'update refs/heads/test DEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF\n' \
    | git update-ref --stdin
```

**Expected**: non-zero exit, `error: unknown revision DEADBEEF...`  
**Actual**: see Docker output — `parse_next_oid` calls `repo_get_oid_with_flags`
which fails, causing immediate error before transaction.

### Test 2: `symref-update` with invalid refname target — the gap

```bash
git init /tmp/r && cd /tmp/r
git commit --allow-empty -m "init"
printf 'symref-update refs/heads/test refs/heads/!!bad!!\n' \
    | git update-ref --stdin
echo "exit: $?"
git symbolic-ref refs/heads/test 2>/dev/null || echo "(not set)"
```

**Hypothesis**: `parse_next_arg` accepts `refs/heads/!!bad!!` without error.
The transaction layer may or may not validate the symref target depending on
the ref backend.

**Actual**: documented in patch cleanroom test output.

### Test 3: `symref-update` with slash-only string

```bash
printf 'symref-update refs/heads/test /\n' \
    | git update-ref --stdin
echo "exit: $?"
```

### Test 4: Comparison — `symref-create` vs `create`

```bash
# create rejects bad OID:
printf 'create refs/heads/test DEADBEEF\n' | git update-ref --stdin

# symref-create with bad refname:
printf 'symref-create refs/heads/test refs/heads/!!bad!!\n' \
    | git update-ref --stdin
```

## Verdict

The finding is **structural** regardless of whether the invalid target is
ultimately stored:

1. If it IS stored: a symref pointing to an invalid target is written, violating
   the refname invariant that `check_refname_format` enforces for all other paths.

2. If it is NOT stored (backend validates): the user gets a late, cryptic error
   message from the ref backend rather than the early, clear message that
   `check_refname_format` would produce.

Either outcome demonstrates the validation depth asymmetry between `parse_next_arg`
and its sibling helpers.
