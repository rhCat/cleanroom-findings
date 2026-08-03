# hermes-agent — /resume and /branch skip context-engine session lifecycle

Upstream: **NousResearch/hermes-agent** @ `a6defd4f1549da3fe1d08d6f746fc645c64543f0`
PR: **#77588** (fixes issue **#77538**) — "cli: notify context engine on /resume and /branch session transitions"

`docker build -t hermes-agent-context-engine . && docker run --rm hermes-agent-context-engine`

Stdlib only, no network. Verdict: RED reproduced + GREEN removed (`ok: true` both phases).

## The code

`hermes_cli/cli_commands_mixin.py:876` and `:1091` (stock, unmodified):

```python
def _handle_resume_command(self, cmd_original):   # :876
    self.agent.session_id = target_id
    self.agent.reset_session_state()              # NO transition metadata
```

`/resume` and `/branch` update both `HermesCLI.session_id` and
`AIAgent.session_id`, then call `agent.reset_session_state()` **without the old
session id or prior transcript**. That runs only the reset half of the external
`ContextEngine` lifecycle. The host transition helper exists
(`run_agent.py:652 _transition_context_engine_session`) and invokes
`on_session_start()` only when transition metadata is present — the two CLI paths
discard that metadata.

An ordinary plugin engine implementing the documented `on_session_end`,
`on_session_reset`, and `on_session_start` hooks is never started on the target
session and can remain bound to the old session, leaking DAG/summary state across
mid-chat session switches.

## The asymmetry

The engine's `on_session_end(old)` → `on_session_start(new)` pair is the
lifecycle; the CLI paths run only the "reset" half. Rebinding without the
transition leaves the engine on the previous session.

## Cleanroom evidence

- RED (stock): `CONTEXT_ENGINE_STUCK_ON_OLD_SESSION` — after /resume,
  `on_session_start` never fires; engine bound to old session.
- GREEN (fix: `_transition_context_engine_session(new_session_id,
  carry_over_context=False)` after the memory switch): `CONTEXT_ENGINE_TRANSITIONED`
  — full `on_session_end(old)` → `on_session_start(new)` lifecycle.
- `verdict.json`: `ok: true` (red + green).
