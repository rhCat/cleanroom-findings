# Bug Cleanroom Status

**Status**: VERIFIED (RED reproduced + GREEN removed) — cleanroom `magnumopus:cleanroom` verify perk
**Date**: 2026-08-03
**Target**: `tools/terminal_tool.py:1759` — `_cleanup_inactive_envs()` refreshes `_last_activity`
only for background-process task ids (`process_registry.has_active_processes`); in-flight foreground
`env.execute()` calls are not protected and get torn down past `lifetime_seconds` (default 300).
**PR**: https://github.com/NousResearch/hermes-agent/pull/77589

## Confirmed Behavior

- RED (stock chamber): foreground command still in flight when the reaper runs → env cleaned up
  underneath it → `IDLE_REAPER_TORE_DOWN_INFLIGHT_FOREGROUND`.
- GREEN (fix chamber, `_foreground_task_ids` in-flight set + activity refresh):
  `IDLE_REAPER_PRESERVED_INFLIGHT_FOREGROUND`.
- `verdict.json`: `{"phases": {"red": {"ok": true}, "green": {"ok": true}}, "ok": true}`
  spec_sha `8c962d74e4266f072585a7a27b42ec83b67546c1c9b6e15590e52680a1604845`.
