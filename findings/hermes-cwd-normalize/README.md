# hermes-agent — session-cwd key normalization + shared-env mutation

Chamber: `c2-cwd-normalize` · spec_sha `8db325f82824b53c6ef4e8bb5a92e66e94d239d4795b802d82ff08595215a724`

Cleanroom RED/GREEN validation for the upstream fix (NousResearch/hermes-agent,
PR counterpart #77585). Minimal extraction of `tools/terminal_tool.py` logic;
stdlib only, no network.

## Run

```sh
docker build -t hermes-cwd-normalize . && docker run --rm hermes-cwd-normalize
```

`RUN_LOG.txt` is the recorded output (RED then GREEN). `verdict.json` is the
engine verdict — `ok: true` for both phases.

## The bug

1. **Stale cwd record (key mismatch):** `record_session_cwd`/`get_session_cwd`
   normalize `None`/empty keys to `"default"`, but `clear_session_cwd` popped
   the raw key verbatim — `clear_task_env_overrides` with a falsy task_id left
   the `"default"` record alive forever, growing the in-memory dict on every
   teardown.
2. **Shared env.cwd mutation cross-session:** `register_task_env_overrides`
   unconditionally set `env.cwd = new_cwd` on the live environment even when
   the override collapsed to the shared `"default"` container, leaking one
   session's working directory into every other session using that container.

## The fix

- `clear_session_cwd` normalizes `str(session_key or "default")` exactly like
  the record/get functions.
- `register_task_env_overrides` tracks which cache key the env was found
  under and only mutates `env.cwd` when the env is genuinely per-session
  (cached under a non-`"default"` key).

## Signatures

| Phase | Output | Meaning |
|---|---|---|
| RED (stock) | `CWD_STALE_RECORD_SURVIVES` | falsy task_id pops raw `""`, `"default"` record leaks forever |
| GREEN (fix) | `CWD_RECORD_CLEARED` | key normalized before pop; record cleared |
