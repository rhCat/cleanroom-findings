# Findings Index

| Finding | Type | Status | Summary |
|---------|------|--------|---------|
| [hermes-idle-reaper-guard](findings/hermes-idle-reaper-guard/) | Bug cleanroom | VERIFIED | `terminal_tool.py::_cleanup_inactive_envs` — in-flight foreground command torn down past `lifetime_seconds`; fix keeps it alive via `_foreground_task_ids` |
| [hermes-cwd-normalize](findings/hermes-cwd-normalize/) | Bug cleanroom | VERIFIED | `terminal_tool.py::clear_session_cwd` — falsy task_id leaves `"default"` record forever; fix normalizes `str(key or "default")` + guards shared env.cwd mutation |
| [hermes-nous-portal-routing](findings/hermes-nous-portal-routing/) | Bug cleanroom | VERIFIED | `nous/__init__.py::build_extra_body` — `provider_preferences` forwarded as `body["provider"]` → Portal HTTP 400; fix drops the forward |
| [hermes-context-engine](findings/hermes-context-engine/) | Bug cleanroom | VERIFIED | `cli_commands_mixin.py` `/resume`+`/branch` skip `_transition_context_engine_session`; fix calls it with `carry_over_context=False` |
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
