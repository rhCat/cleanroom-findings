# Bug Cleanroom Status

**Status**: VERIFIED (RED reproduced + GREEN removed) — cleanroom `magnumopus:cleanroom` verify perk
**Date**: 2026-08-03
**Target**: `tools/terminal_tool.py:1178+` — `clear_session_cwd()` pops the raw key while
`record_session_cwd()`/`get_session_cwd()` normalize `None`/empty to `"default"`; a falsy task_id on
teardown leaves the `"default"` record alive forever. `register_task_env_overrides` also mutates the
shared `env.cwd` cross-session when the container collapses to `"default"`.
**PR**: https://github.com/NousResearch/hermes-agent/pull/77585

## Confirmed Behavior

- RED (stock chamber): `record_session_cwd(None, …)` stores under `"default"`;
  `clear_task_env_overrides("")` pops `""` → miss → record survives →
  `CWD_STALE_RECORD_SURVIVES`.
- GREEN (fix chamber, key normalized before pop):
  `CWD_RECORD_CLEARED`.
- `verdict.json`: `{"phases": {"red": {"ok": true}, "green": {"ok": true}}, "ok": true}`
  spec_sha `8db325f82824b53c6ef4e8bb5a92e66e94d239d4795b802d82ff08595215a724`.
