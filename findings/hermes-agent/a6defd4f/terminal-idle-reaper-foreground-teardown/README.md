# hermes-agent — idle reaper tears down in-flight foreground commands

Upstream: **NousResearch/hermes-agent** @ `a6defd4f1549da3fe1d08d6f746fc645c64543f0`
PR: **#77589** — "fix(terminal): guard foreground commands from idle reaper teardown"

`docker build -t hermes-agent-idle-reaper . && docker run --rm hermes-agent-idle-reaper`

Stdlib only, no network. Verdict: RED reproduced + GREEN removed (`ok: true` both phases).

## The code

`tools/terminal_tool.py:1759` (stock, unmodified):

```python
def _cleanup_inactive_envs(lifetime_seconds: int = 300):
    ...
    try:
        from tools.process_registry import process_registry
        for task_id in list(_last_activity.keys()):
            if process_registry.has_active_processes(task_id):
                _last_activity[task_id] = current_time  # Keep sandbox alive
    except ImportError:
        pass
```

`_last_activity` is refreshed **only** for task ids with background processes.
A foreground `env.execute()` command that runs longer than `lifetime_seconds`
(default 300s) has its sandbox removed from underneath it: the reaper's phase-1
stale sweep pops the env and calls `env.cleanup()` while the synchronous
foreground call is still running. Found by the V12 security audit (run #5937).

## The asymmetry

Background processes keep their env alive via `has_active_processes()`; in-flight
**foreground** task ids have no equivalent refresh. A command that legitimately
runs past the lifetime window is torn down mid-execution — the sandbox (Modal /
Docker / SSH) is cleaned under the running call.

## Cleanroom evidence

- RED (stock): `IDLE_REAPER_TORE_DOWN_INFLIGHT_FOREGROUND` — foreground command
  still in flight when the reaper runs is torn down.
- GREEN (fix: module-level `_foreground_task_ids`; refresh activity for any task
  with a foreground command in flight): `IDLE_REAPER_PRESERVED_INFLIGHT_FOREGROUND`.
- `verdict.json`: `ok: true` (red + green).

Chamber: `repro/` (stock) + `repro/fix/` (overlay), scaffolded from the governed
`magnumopus:cleanroom` verify perk.
