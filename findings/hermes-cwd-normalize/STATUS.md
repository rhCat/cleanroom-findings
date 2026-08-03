# Bug Cleanroom Status

**Status**: VERIFIED — RED reproduced on stock logic, GREEN (fix overlay) removes it
**Date**: 2026-08-03
**Target**: `tools/terminal_tool.py::clear_session_cwd` /
`register_task_env_overrides` — stale cwd record on falsy task_id + shared
`env.cwd` mutation leaking one session's cwd into every other
**Upstream issue/PR**: NousResearch/hermes-agent#77585 (other author); this
cleanroom certifies the premise and the fix shape
**Analyzed commit**: `a6defd4f1549da3fe1d08d6f746fc645c64543f0`
**Chamber**: `c2-cwd-normalize` · spec_sha `8db325f82824…`
**Engine**: `magnumopus:cleanroom` verify perk, `PHASE=both`

## Confirmed Behavior

- RED (stock): `record_session_cwd(None, …)` stores under `"default"`;
  `clear_task_env_overrides("")` pops raw `""` → miss; the `"default"` record
  survives → `CWD_STALE_RECORD_SURVIVES`.
- GREEN (fix): `clear_session_cwd` normalizes `str(key or "default")` before
  popping → `CWD_RECORD_CLEARED`.

## Verdict

`verdict.json`: `ok: true` for both phases. The premise is real at the
analyzed commit and the fix shape removes it.
