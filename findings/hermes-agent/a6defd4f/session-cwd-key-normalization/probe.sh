#!/bin/sh
# Chamber for PR #77585: session-cwd key normalization.
# Minimal extraction of terminal_tool logic:
#   - record_session_cwd(None, cwd) stores under normalized key "default"
#   - clear_session_cwd("") pops the RAW key "" -> miss -> record survives
#   - every teardown re-adds a new "default" record (growth)
#
# RED (stock): after record + clear with falsy key, the record survives ->
#   prints CWD_STALE_RECORD_SURVIVES (and the dict grew)
# GREEN (fix): clear normalizes the key -> record removed ->
#   prints CWD_RECORD_CLEARED

python3 - <<'PY'
import time

# ---- minimal extraction of tools/terminal_tool.py (stock = RED) ----

_session_cwd_records = {}  # session_key -> cwd

def record_session_cwd(session_key, cwd):
    # Stock: normalizes None/empty to "default"
    key = str(session_key or "default")
    _session_cwd_records[key] = cwd

def clear_session_cwd(session_key):
    # Stock BUG: pops the RAW key verbatim — no normalization.
    _session_cwd_records.pop(session_key, None)

def clear_task_env_overrides(task_id):
    # Stock: calls clear_session_cwd(task_id) with the raw (possibly falsy) id.
    clear_session_cwd(task_id)

# ---- probe: teardown with a falsy task_id after a record was written ----

record_session_cwd(None, "/work/proj")   # stored under "default"
before = len(_session_cwd_records)       # 1

clear_task_env_overrides("")             # pops "" — misses "default"

after = len(_session_cwd_records)        # still 1 -> stale record survives

if after == before and "default" in _session_cwd_records:
    print("CWD_STALE_RECORD_SURVIVES")
    raise SystemExit(0)
else:
    print("CWD_RECORD_CLEARED")
    raise SystemExit(0)
PY
