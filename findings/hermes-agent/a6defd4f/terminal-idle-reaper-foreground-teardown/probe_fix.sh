#!/bin/sh
# Chamber for PR #77589 — GREEN build (fix applied).
# The reaper now refreshes _last_activity for in-flight FOREGROUND task ids
# too (module-level _foreground_task_ids), so a long foreground command is
# preserved instead of torn down.

python3 - <<'PY'
import time

_last_activity = {}
_active_environments = {}
_inflight_foreground = set()  # PR fix: module-level _foreground_task_ids

class FakeEnv:
    def __init__(self, task_id):
        self.task_id = task_id
        self.cleaned_up = False
    def cleanup(self):
        self.cleaned_up = True

def has_active_processes(task_id):
    return False

def run_foreground_command(task_id, duration):
    _last_activity[task_id] = time.time()
    _inflight_foreground.add(task_id)
    try:
        time.sleep(duration)
    finally:
        _inflight_foreground.discard(task_id)

def _cleanup_inactive_envs(lifetime_seconds):
    current_time = time.time()
    # FIX (PR #77589): refresh for BOTH background processes and in-flight
    # foreground commands, so neither is torn down mid-execution.
    for task_id in list(_last_activity.keys()):
        if has_active_processes(task_id) or task_id in _inflight_foreground:
            _last_activity[task_id] = current_time
    envs_to_stop = []
    for task_id, last_time in list(_last_activity.items()):
        if current_time - last_time > lifetime_seconds:
            env = _active_environments.pop(task_id, None)
            _last_activity.pop(task_id, None)
            if env is not None:
                envs_to_stop.append((task_id, env))
    for task_id, env in envs_to_stop:
        env.cleanup()

env = FakeEnv("t1")
_active_environments["t1"] = env

import threading
t = threading.Thread(target=run_foreground_command, args=("t1", 3.0))
t.start()

time.sleep(0.2)
_last_activity["t1"] = time.time() - 2.0

_cleanup_inactive_envs(lifetime_seconds=1)

t.join()

if env.cleaned_up:
    print("IDLE_REAPER_TORE_DOWN_INFLIGHT_FOREGROUND")
    raise SystemExit(0)
else:
    print("IDLE_REAPER_PRESERVED_INFLIGHT_FOREGROUND")
    raise SystemExit(0)
PY
