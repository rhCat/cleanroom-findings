# Bug Cleanroom Status

**Status**: VERIFIED — RED reproduced on stock logic, GREEN (fix overlay) removes it
**Date**: 2026-08-03
**Target**: `tools/terminal_tool.py::_cleanup_inactive_envs` — idle reaper tears
down a sandbox whose foreground `env.execute()` is still in flight past
`lifetime_seconds` (default 300)
**Upstream issue/PR**: NousResearch/hermes-agent#77589 (other author); this
cleanroom certifies the premise and the fix shape
**Analyzed commit**: `a6defd4f1549da3fe1d08d6f746fc645c64543f0`
**Chamber**: `c1-idle-reaper` · spec_sha `8c962d74e426…`
**Engine**: `magnumopus:cleanroom` verify perk, `PHASE=both`

## Confirmed Behavior

- RED (stock): reaper refreshes `_last_activity` only for background-process
  task ids; the in-flight foreground env (command lasting 3s, reaper at 1s
  lifetime) is torn down → `IDLE_REAPER_TORE_DOWN_INFLIGHT_FOREGROUND`.
- GREEN (fix): `_foreground_task_ids` membership refreshes activity for the
  in-flight foreground env → `IDLE_REAPER_PRESERVED_INFLIGHT_FOREGROUND`.

## Verdict

`verdict.json`: `ok: true` for both phases. The premise is real at the
analyzed commit and the fix shape removes it.
