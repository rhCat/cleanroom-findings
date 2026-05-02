# Findings Index

| Finding | Type | Status | Summary |
|---------|------|--------|---------|
| [git-hook-return-discard](findings/git-hook-return-discard/) | Bug cleanroom | DRAFT | `refs.c:2736` — `run_transaction_hook("committed")` return discarded; push side-effects silently lost |
| [git-hook-return-discard-patch](findings/git-hook-return-discard-patch/) | Patch cleanroom | VERIFIED | `warning()` added to surface committed-phase hook failure; `git push` still exits 0 |
| [git-merge-ort-rename-pipeline-discard](findings/git-merge-ort-rename-pipeline-discard/) | Bug cleanroom (doc-only) | DRAFT | `merge-ort.c` — rename pipeline has no `-1` error path; silent wrong-tree merge under production failure |
| [git-merge-ort-rename-pipeline-discard-patch](findings/git-merge-ort-rename-pipeline-discard-patch/) | Patch cleanroom | VERIFIED | Error path wired through pipeline; simulated failure exits 2, no wrong tree committed |
