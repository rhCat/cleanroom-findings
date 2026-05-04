# Source Citations — update-ref parse_next_arg validation gap

Git version: v2.49.0 (`7d5bb9c6`)  
Investigation version: v2.49.0 — symref commands added post-2.43.7

---

## `parse_arg` — shared base parser
**File**: `builtin/update-ref.c`  
**Approx line**: 30 (v2.49.0)

```c
static const char *parse_arg(const char *next, struct strbuf *arg)
{
    strbuf_reset(arg);
    if (*next == '"') {
        const char *orig = next;
        if (strbuf_dequote_path(arg, &next))
            die("badly quoted argument: %s", orig);
    } else {
        while (*next && !isspace(*next))
            strbuf_addch(arg, *next++);
    }
    return next;
}
```

---

## `parse_refname` — validates refname format
**File**: `builtin/update-ref.c`  
**Approx line**: 55 (v2.49.0)

```c
static char *parse_refname(const char **next)
{
    struct strbuf ref = STRBUF_INIT;
    /* ... skip delimiter ... */
    (*next)++;
    return parse_refname(next);  /* ← calls check_refname_format internally */
}
```

---

## `parse_next_refname` — validated wrapper for symref targets
**File**: `builtin/update-ref.c`  
**Approx line**: 82 (v2.49.0)

```c
static char *parse_next_refname(const char **next)
{
    /* ... skip delimiter ... */
    (*next)++;
    return parse_refname(next);  /* ← VALIDATES via check_refname_format */
}
```

Used for: `<new-target>` in `symref-update`, `symref-create`, `symref-delete`,
`symref-verify`. Correctly validated.

---

## `parse_next_arg` — no semantic validation
**File**: `builtin/update-ref.c`  
**Approx line**: 106 (v2.49.0)

```c
static char *parse_next_arg(const char **next)
{
    struct strbuf arg = STRBUF_INIT;
    /* ... skip delimiter ... */
    (*next)++;
    /* ... parse ... */
    if (arg.len)
        return strbuf_detach(&arg, NULL);
    return NULL;  /* ← only check: non-empty. No refname or domain validation. */
}
```

Used for: `old_arg` (type specifier) and `old_target` (value) in `symref-update`.
`old_target` is validated CONDITIONALLY after parsing, based on `old_arg` type.

---

## FlowAsymmetry: parse_next_arg vs parse_next_refname

`parse_next_refname` and `parse_next_arg` are adjacent functions with similar
call signatures. Their validation profiles differ significantly:

```
parse_next_refname: skip_delim → parse_refname → check_refname_format → die on invalid
parse_next_arg:     skip_delim → parse_arg → (no domain validation)
```

The `parse_cmd_symref_update` function calls both:
- `parse_next_refname` for `new_target` (validated at parse time)
- `parse_next_arg` for `old_arg` and `old_target` (validated conditionally later)

The conditional validation for `old_target` is:
```c
old_arg = parse_next_arg(&next);
if (old_arg) {
    old_target = parse_next_arg(&next);  /* ← unvalidated at parse time */
    if (!strcmp(old_arg, "oid")) {
        repo_get_oid(...);   /* late OID validation */
    } else if (!strcmp(old_arg, "ref")) {
        check_refname_format(old_target, ...);  /* late refname validation */
    } else {
        die(...);
    }
}
```

The structural gap: `parse_next_arg` exists as an unvalidated helper adjacent
to `parse_next_refname`. Future code additions could accidentally use
`parse_next_arg` instead of `parse_next_refname` for refname-type arguments.

---

## Version note: symref support added post-2.43.7

`parse_next_arg`, `parse_next_refname`, and symref commands (`symref-update`,
`symref-create`, `symref-delete`, `symref-verify`) were NOT present in git 2.43.7.
They were added in git 2.49.0. The patch Dockerfile uses git 2.49.0 accordingly.
