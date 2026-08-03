# hermes-agent — idle reaper tears down in-flight foreground commands

Chamber: `c1-idle-reaper` · spec_sha `8c962d74e4266f072585a7a27b42ec83b67546c1c9b6e15590e52680a1604845`

Cleanroom RED/GREEN validation for the upstream fix (NousResearch/hermes-agent,
PR counterpart #77589). Minimal extraction of `tools/terminal_tool.py` logic;
stdlib only, no network.

## Run

```sh
docker build -t hermes-idle-reaper-guard . && docker run --rm hermes-idle-reaper-guard
```

`RUN_LOG.txt` is the recorded output (RED then GREEN). `verdict.json` is the
engine verdict — `ok: true` for both phases.

## The bug

`_cleanup_inactive_envs(lifetime_seconds=300)` refreshes `_last_activity` only
for task ids with **background** processes
(`process_registry.has_active_processes`). A long-running **foreground**
`env.execute()` — not registered in the process registry — that runs past
`lifetime_seconds` has its sandbox torn down from underneath it.
`_last_activity` is bumped at command start only, never during the call.

## The fix

- module-level `_foreground_task_ids: set[str]` (protected by `_env_lock`)
- the foreground `env.execute()` adds `effective_task_id` before the call,
  discards it in a `finally`
- `_cleanup_inactive_envs` refreshes `_last_activity` for every in-flight
  foreground id, mirroring the background-process refresh

## Signatures

| Phase | Output | Meaning |
|---|---|---|
| RED (stock) | `IDLE_REAPER_TORE_DOWN_INFLIGHT_FOREGROUND` | in-flight foreground command torn down |
| GREEN (fix) | `IDLE_REAPER_PRESERVED_INFLIGHT_FOREGROUND` | in-flight foreground preserved |
