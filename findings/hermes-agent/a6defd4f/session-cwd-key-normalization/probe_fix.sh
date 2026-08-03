#!/bin/sh
# Chamber for PR #77585 — GREEN build (fix applied).
# clear_session_cwd normalizes the key before popping.

python3 - <<'PY'
_session_cwd_records = {}

def record_session_cwd(session_key, cwd):
    key = str(session_key or "default")
    _session_cwd_records[key] = cwd

def clear_session_cwd(session_key):
    # FIX (PR #77585): normalize exactly like record/get.
    key = str(session_key or "default")
    _session_cwd_records.pop(key, None)

def clear_task_env_overrides(task_id):
    clear_session_cwd(task_id)

record_session_cwd(None, "/work/proj")
before = len(_session_cwd_records)

clear_task_env_overrides("")

after = len(_session_cwd_records)

if after == before and "default" in _session_cwd_records:
    print("CWD_STALE_RECORD_SURVIVES")
    raise SystemExit(0)
else:
    print("CWD_RECORD_CLEARED")
    raise SystemExit(0)
PY
