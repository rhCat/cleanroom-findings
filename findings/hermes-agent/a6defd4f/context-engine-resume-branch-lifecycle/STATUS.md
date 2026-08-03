# Bug Cleanroom Status

**Status**: VERIFIED (RED reproduced + GREEN removed) — cleanroom `magnumopus:cleanroom` verify perk
**Date**: 2026-08-03
**Target**: `hermes_cli/cli_commands_mixin.py:876` (`_handle_resume_command`) and `:1091`
(`_handle_branch_command`) — both update session state + memory manager but never call
`agent._transition_context_engine_session()`, so the external ContextEngine stays bound to the
previous session_id and leaks DAG/summary state across mid-chat session switches (issue #77538).
**PR**: https://github.com/NousResearch/hermes-agent/pull/77588
**Issue**: https://github.com/NousResearch/hermes-agent/issues/77538

## Confirmed Behavior

- RED (stock chamber): /resume calls `reset_session_state()` without transition
  metadata; `on_session_start` never fires; engine bound to old session →
  `CONTEXT_ENGINE_STUCK_ON_OLD_SESSION`.
- GREEN (fix chamber: `_transition_context_engine_session(new_session_id,
  carry_over_context=False)` after the memory switch) → full
  `on_session_end(old)` → `on_session_start(new)` lifecycle →
  `CONTEXT_ENGINE_TRANSITIONED`.
- `verdict.json`: `{"phases": {"red": {"ok": true}, "green": {"ok": true}}, "ok": true}`
  spec_sha `7327981e3c62f4cbfe85e886fcb74958a1f7fd952fe2121e9acb71418f3ceec8`.
