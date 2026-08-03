# hermes-agent — session-cwd key normalization leak

Upstream: **NousResearch/hermes-agent** @ `a6defd4f1549da3fe1d08d6f746fc645c64543f0`
PR: **#77585** — "fix(terminal): normalize session key in clear_session_cwd and guard shared env mutation"

`docker build -t hermes-agent-cwd-normalize . && docker run --rm hermes-agent-cwd-normalize`

Stdlib only, no network. Verdict: RED reproduced + GREEN removed (`ok: true` both phases).

## The code

`tools/terminal_tool.py` (stock, unmodified):

```python
def record_session_cwd(session_key, cwd):      # :1178
    key = str(session_key or "default")        # normalizes None/empty -> "default"
    _session_cwd_records[key] = cwd

def clear_session_cwd(session_key):            # stock BUG
    _session_cwd_records.pop(session_key, None)   # pops the RAW key verbatim
```

`clear_task_env_overrides(task_id)` calls `clear_session_cwd(task_id)` with a
falsy `task_id` on teardown — the raw `""` pop misses the normalized `"default"`
record, which survives forever and the in-memory dict grows on every teardown.

## The asymmetry

`record_session_cwd` and `get_session_cwd` normalize the key
(`str(session_key or "default")`); `clear_session_cwd` does not. Write and read
agree on a key namespace; the delete path uses a different one. Also
`register_task_env_overrides` mutates the shared `env.cwd` cross-session when the
container collapses to `"default"` (CWD-only overrides).

## Cleanroom evidence

- RED (stock): `CWD_STALE_RECORD_SURVIVES` — falsy task_id pop misses the
  normalized `"default"` record; it survives.
- GREEN (fix: normalize in `clear_session_cwd`): `CWD_RECORD_CLEARED`.
- `verdict.json`: `ok: true` (red + green).

Chamber: `repro/` (stock) + `repro/fix/` (overlay), scaffolded from the governed
`magnumopus:cleanroom` verify perk.
