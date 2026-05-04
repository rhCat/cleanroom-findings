/*
 * Source reference: merge-ort.c — merge_ort_internal
 * Git version: v2.49.0 (7d5bb9c6) / HEAD (e895506107)
 * Approx lines: 5310–5390
 *
 * Finding: make_virtual_commit return not checked for NULL at lines 5335, 5374.
 * Downstream dereferences of ->parents at 5377 and 5384 would crash if NULL.
 *
 * Path scrubbed: internal analysis paths removed.
 */

static void merge_ort_internal(struct merge_options *opt,
			       struct commit_list *merge_bases,
			       struct commit *h1,
			       struct commit *h2,
			       struct merge_result *result)
{
	struct commit *next;
	struct commit *merged_merge_bases;
	const char *ancestor_name;
	struct strbuf merge_base_abbrev = STRBUF_INIT;

	if (!merge_bases) {
		merge_bases = get_merge_bases(h1, h2);
		merge_bases = reverse_commit_list(merge_bases);
	}

	merged_merge_bases = pop_commit(&merge_bases);
	if (!merged_merge_bases) {
		/* if there is no common ancestor, use an empty tree */
		struct tree *tree;

		tree = lookup_tree(opt->repo, opt->repo->hash_algo->empty_tree);
		merged_merge_bases = make_virtual_commit(opt->repo, tree,
							 "ancestor");
		/* FINDING: no NULL check here — if make_virtual_commit returns
		 * NULL, merged_merge_bases is NULL and downstream
		 * commit_list_insert(&NULL->parents) crashes. */
		ancestor_name = "empty tree";
	} else if (merge_bases) {
		ancestor_name = "merged common ancestors";
	} else {
		strbuf_reset(&merge_base_abbrev);
		strbuf_add_unique_abbrev(&merge_base_abbrev,
					 &merged_merge_bases->object.oid,
					 DEFAULT_ABBREV);
		ancestor_name = merge_base_abbrev.buf;
	}

	for (next = pop_commit(&merge_bases); next; next = pop_commit(&merge_bases)) {
		const char *saved_prefix = opt->priv ? opt->priv->prefix : NULL;
		struct merge_result tmp_result;
		struct commit *prev = merged_merge_bases;

		opt->priv = NULL;
		memset(&tmp_result, 0, sizeof(tmp_result));
		merge_ort_internal(opt, NULL, prev, next, &tmp_result);
		/* Note: result->clean < 0 IS checked here — asymmetry with
		 * make_virtual_commit below which is NOT checked. */
		if (tmp_result.clean < 0)
			goto out;

		merged_merge_bases = make_virtual_commit(opt->repo,
							 tmp_result.tree,
							 "merged tree");
		/* FINDING: no NULL check here — if make_virtual_commit returns
		 * NULL, the next two lines dereference NULL->parents. */
		commit_list_insert(prev, &merged_merge_bases->parents);
		commit_list_insert(next, &merged_merge_bases->parents->next);
		                        /* ↑ SIGSEGV if merged_merge_bases is NULL */

		clear_or_reinit_internal_opts(opt->priv, 1);
		opt->priv = NULL;
	}

	/* ... rest of function: calls merge_ort_nonrecursive_internal ... */

out:
	strbuf_release(&merge_base_abbrev);
}
