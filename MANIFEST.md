# Findings Index

| Finding | Type | Status | Summary |
|---------|------|--------|---------|
| [git-hook-return-discard](findings/git-hook-return-discard/) | Bug cleanroom | DRAFT | `refs.c:2736` — `run_transaction_hook("committed")` return discarded; push side-effects silently lost |
| [git-hook-return-discard-patch](findings/git-hook-return-discard-patch/) | Patch cleanroom | VERIFIED | `warning()` added to surface committed-phase hook failure; `git push` still exits 0 |
| [git-merge-ort-rename-pipeline-discard](findings/git-merge-ort-rename-pipeline-discard/) | Bug cleanroom (doc-only) | DRAFT | `merge-ort.c` — rename pipeline has no `-1` error path; silent wrong-tree merge under production failure |
| [git-merge-ort-rename-pipeline-discard-patch](findings/git-merge-ort-rename-pipeline-discard-patch/) | Patch cleanroom | VERIFIED | Error path wired through pipeline; simulated failure exits 2, no wrong tree committed |
| [git-merge-ort-make-virtual-commit-error-discard](findings/git-merge-ort-make-virtual-commit-error-discard/) | Bug cleanroom (doc-only) | DRAFT | `merge-ort.c` — `make_virtual_commit` return not NULL-checked; latent SIGSEGV in recursive merge base loop |
| [git-merge-ort-make-virtual-commit-error-discard-patch](findings/git-merge-ort-make-virtual-commit-error-discard-patch/) | Patch cleanroom | VERIFIED | NULL guards added at both call sites; `die()` fires instead of SIGSEGV when hook injects NULL |
| [git-update-ref-parse-arg-inconsistency](findings/git-update-ref-parse-arg-inconsistency/) | Bug cleanroom | DRAFT | `builtin/update-ref.c` — `parse_next_arg` has no post-parse refname validation; symref targets accepted without format check |
| [git-update-ref-parse-arg-inconsistency-patch](findings/git-update-ref-parse-arg-inconsistency-patch/) | Patch cleanroom | VERIFIED | `parse_next_symref_target` added with `check_refname_format`; invalid symref targets rejected at parse time |
| [turbofit-model-resident-fail-open](findings/turbofit-model-resident-fail-open/) | Bug cleanroom | CONFIRMED | `turbohaul_client.py:227` — `_model_is_resident()` returns False for any unrecognised status shape; the unload-verification loop reads that as "unloaded" and returns success on the first poll, making its `TurbohaulClientError` timeout unreachable |
| [turbofit-model-resident-fail-open-patch](findings/turbofit-model-resident-fail-open-patch/) | Patch cleanroom | VERIFIED | unreadable status now fails CLOSED (stays resident) so the timeout fires; empty/non-matching `residents` list still a proven absence, genuine unload unchanged |
| [hermes-agent/a6defd4f/terminal-idle-reaper-foreground-teardown](findings/hermes-agent/a6defd4f/terminal-idle-reaper-foreground-teardown/) | Bug cleanroom | VERIFIED | `terminal_tool.py:1759` — `_cleanup_inactive_envs()` refreshes `_last_activity` only for background-process task ids; in-flight foreground `env.execute()` torn down past `lifetime_seconds` (PR #77589) |
