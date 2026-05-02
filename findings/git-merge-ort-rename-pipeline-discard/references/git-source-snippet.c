/*
 * Relevant merge-ort.c excerpts for rename-pipeline-discard finding.
 * Source: git HEAD (post-v2.49.0, e895506107)
 * Lines are approximate — check the actual source for exact numbers.
 */

/* -----------------------------------------------------------------------
 * detect_regular_renames (~line 3423)
 * Returns 0 (not needed) or 1 (ran). NO -1 error path.
 * ----------------------------------------------------------------------- */
static int detect_regular_renames(struct merge_options *opt,
				  unsigned side_index)
{
	struct diff_options diff_opts;
	struct rename_info *renames = &opt->priv->renames;

	prune_cached_from_relevant(renames, side_index);
	if (!possible_side_renames(renames, side_index)) {
		resolve_diffpair_statuses(&renames->pairs[side_index]);
		return 0;  /* detection not needed */
	}

	partial_clear_dir_rename_count(&renames->dir_rename_count[side_index]);
	repo_diff_setup(opt->repo, &diff_opts);
	/* ... diff_opts setup ... */
	diff_setup_done(&diff_opts);

	diff_queued_diff = renames->pairs[side_index];
	trace2_region_enter("diff", "diffcore_rename", opt->repo);

	/*
	 * FINDING: diffcore_rename_extended return value is NOT checked.
	 * If it fails internally (OOM, missing objects, signal), the failure
	 * is undetectable here.
	 */
	diffcore_rename_extended(&diff_opts,
				 &opt->priv->pool,
				 &renames->relevant_sources[side_index],
				 &renames->dirs_removed[side_index],
				 &renames->dir_rename_count[side_index],
				 &renames->cached_pairs[side_index]);
	trace2_region_leave("diff", "diffcore_rename", opt->repo);

	resolve_diffpair_statuses(&diff_queued_diff);

	if (diff_opts.needed_rename_limit > 0)
		renames->redo_after_renames = 0;
	if (diff_opts.needed_rename_limit > renames->needed_limit)
		renames->needed_limit = diff_opts.needed_rename_limit;

	renames->pairs[side_index] = diff_queued_diff;

	diff_opts.output_format = DIFF_FORMAT_NO_OUTPUT;
	diff_queued_diff.nr = 0;
	diff_queued_diff.queue = NULL;
	diff_flush(&diff_opts);

	return 1;  /* always 1 if we reached here — no -1 for errors */
}

/* -----------------------------------------------------------------------
 * detect_and_process_renames (~line 3547) — the caller
 * ----------------------------------------------------------------------- */
static int detect_and_process_renames(struct merge_options *opt)
{
	struct diff_queue_struct combined = { 0 };
	struct rename_info *renames = &opt->priv->renames;
	struct strmap collisions[3];
	int need_dir_renames, s, i, clean = 1;
	unsigned detection_run = 0;

	if (!possible_renames(renames))
		goto cleanup;
	if (!opt->detect_renames) {
		renames->redo_after_renames = 0;
		renames->cached_pairs_valid_side = 0;
		goto cleanup;
	}

	trace2_region_enter("merge", "regular renames", opt->repo);

	/*
	 * FINDING: |= accumulation cannot distinguish 0 (not needed),
	 * 1 (ran OK), or -1 (ran but failed). If detect_regular_renames
	 * returns 1 after a silent failure, detection_run is truthy and
	 * the pipeline continues with empty renames->pairs.
	 */
	detection_run |= detect_regular_renames(opt, MERGE_SIDE1);
	detection_run |= detect_regular_renames(opt, MERGE_SIDE2);

	/* ... redo_after_renames check ... */

	/* collect_renames with &= — propagates "has conflicts" but not errors */
	clean &= collect_renames(opt, &combined, MERGE_SIDE1, collisions,
				 &renames->dir_renames[2],
				 &renames->dir_renames[1]);
	clean &= collect_renames(opt, &combined, MERGE_SIDE2, collisions,
				 &renames->dir_renames[1],
				 &renames->dir_renames[2]);

	STABLE_QSORT(combined.queue, combined.nr, compare_pairs);

	clean &= process_renames(opt, &combined);
	/* ... */

cleanup:
	/* ... free pairs ... */
simple_cleanup:
	diff_queue_clear(&combined);
	return clean;
}

/* -----------------------------------------------------------------------
 * The caller: merge_ort_nonrecursive_internal (~line 5272)
 * ----------------------------------------------------------------------- */
/*
 * result->clean = detect_and_process_renames(opt);
 *
 * If detect_and_process_renames returns 1 (clean) with wrong rename data,
 * result->clean = 1, process_entries writes the wrong tree, and:
 *
 * if (result->clean >= 0) {
 *     result->tree = repo_parse_tree_indirect(opt->repo, &working_tree_oid);
 *     result->clean &= strmap_empty(&opt->priv->conflicted);
 * }
 *
 * result->tree points to the wrong tree. The merge command exits 0.
 */

/* -----------------------------------------------------------------------
 * PROPOSED FIX (detect_and_process_renames):
 * ----------------------------------------------------------------------- */

	/* Replace |= with explicit error check */
	if (detect_regular_renames(opt, MERGE_SIDE1) < 0 ||
	    detect_regular_renames(opt, MERGE_SIDE2) < 0) {
		error(_("rename detection failed; aborting merge to prevent "
			"tree corruption"));
		clean = -1;
		goto cleanup;
	}
	detection_run = 1;

/*
 * With clean = -1:
 *   result->clean = -1
 *   builtin/merge.c: if (clean < 0) { rollback_lock_file(&lock); return 2; }
 *   Merge aborts cleanly. No wrong tree committed.
 */
