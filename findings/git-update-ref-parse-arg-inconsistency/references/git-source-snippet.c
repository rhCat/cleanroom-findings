/*
 * Source reference: builtin/update-ref.c — argument parsing helpers
 * Git version: v2.49.0 (7d5bb9c6)
 * Approx lines: 30–150 (parse_arg, parse_refname, parse_next_refname, parse_next_arg)
 *
 * Finding: parse_next_arg (no domain validation) vs parse_next_refname (validates)
 * Both used in symref command handlers; parse_next_arg is a latent misuse trap.
 *
 * Note: symref commands not present in v2.43.7. Added in v2.49.0.
 * Path scrubbed: internal analysis paths removed.
 */

/* ── Shared base parser ──────────────────────────────────────────────────── */

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

/* ── parse_refname — validates refname format ────────────────────────────── */

static char *parse_refname(const char **next)
{
	struct strbuf ref = STRBUF_INIT;

	/* ... check_refname_format called internally ... */
	if (check_refname_format(ref.buf, REFNAME_ALLOW_ONELEVEL))
		die("invalid ref format: %s", ref.buf);  /* ← VALIDATED */
	return strbuf_detach(&ref, NULL);
}

/* ── parse_next_refname — validated wrapper for symref targets ───────────���─ */

static char *parse_next_refname(const char **next)
{
	/* ... skip delimiter ... */
	(*next)++;
	return parse_refname(next);  /* ← VALIDATES via check_refname_format */
}

/*
 * Used for: new_target in symref-update, symref-create, symref-delete,
 * symref-verify. Correctly validated at parse time.
 */

/* ── parse_next_arg — NO semantic validation ─────────────────────────────── */

static char *parse_next_arg(const char **next)
{
	struct strbuf arg = STRBUF_INIT;

	if (line_termination) {
		if (!**next || **next == line_termination)
			return NULL;
		if (**next != ' ')
			die("expected SP but got: %s", *next);
	} else {
		if (**next)
			return NULL;
	}
	(*next)++;

	if (line_termination) {
		*next = parse_arg(*next, &arg);
	} else {
		strbuf_addstr(&arg, *next);
		*next += arg.len;
	}

	if (arg.len)
		return strbuf_detach(&arg, NULL);

	strbuf_release(&arg);
	return NULL;
	/* ← ONLY check: non-empty. No refname or domain validation. */
}

/*
 * Used for: old_arg type specifier ("oid"/"ref") and old_target VALUE
 * in symref-update. old_target validated CONDITIONALLY after this call
 * based on old_arg type — complex two-step validation:
 *
 *   old_arg = parse_next_arg(&next);       // no validation at parse time
 *   if (old_arg) {
 *       old_target = parse_next_arg(&next); // no validation at parse time
 *       if (!strcmp(old_arg, "ref"))
 *           check_refname_format(old_target, ...);  // late, conditional
 *       else if (!strcmp(old_arg, "oid"))
 *           repo_get_oid(old_target, ...);          // late, conditional
 *       else die(...);
 *   }
 *
 * ASYMMETRY: parse_next_refname validates unconditionally at parse time;
 * parse_next_arg defers validation (or skips it for type specifiers).
 * A future code addition could accidentally use parse_next_arg instead of
 * parse_next_refname for a refname-type argument.
 */
