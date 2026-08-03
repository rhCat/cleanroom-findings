#!/bin/sh
# Chamber for PR #77589: idle reaper tears down an env while its foreground
# command is still in flight. Minimal extraction of terminal_tool logic:
#   - _last_activity[task] set at command start
#   - _cleanup_inactive_envs refreshes ONLY background-process task ids
#     (process_registry.has_active_processes), never in-flight foreground ids
#   - a foreground "command" that runs past lifetime_seconds is torn down
#     (env.cleanup called) even though it is still executing.
#
# RED (stock): the reaper kills the in-flight foreground env ->
#   prints IDLE_REAPER_TORE_DOWN_INFLIGHT_FOREGROUND
# GREEN (fix): the reaper sees the in-flight foreground task and keeps it alive
#   -> prints IDLE_REAPER_PRESERVED_INFLIGHT_FOREGROUND

python3 - <<'PY'
import time

# ---- minimal extraction of tools/terminal_tool.py logic (stock = RED) ----

_last_activity = {}       # task_id -> last activity timestamp
_active_environments = {} # task_id -> fake env object
_inflight_foreground = set()  # task ids with a foreground command in flight

class FakeEnv:
    def __init__(self, task_id):
        self.task_id = task_id
        self.cleaned_up = False
    def cleanup(self):
        self.cleaned_up = True

def has_active_processes(task_id):
    # process_registry.has_active_processes — background processes only.
    return False

def run_foreground_command(task_id, duration):
    # env.execute() equivalent: register activity at start, then run.
    _last_activity[task_id] = time.time()
    _inflight_foreground.add(task_id)
    try:
        time.sleep(duration)  # simulate the long-running foreground command
    finally:
        _inflight_foreground.discard(task_id)

def _cleanup_inactive_envs(lifetime_seconds):
    current_time = time.time()
    # Stock bug: refresh _last_activity ONLY for background processes.
    # The PR's fix also refreshes for in-flight FOREGROUND task ids.
    for task_id in list(_last_activity.keys()):
        if has_active_processes(task_id):
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

# ---- probe: start a foreground command lasting 3s, reaper runs at 1s ----

env = FakeEnv("t1")
_active_environments["t1"] = env

# Start the long foreground command in a thread.
import threading
t = threading.Thread(target=run_foreground_command, args=("t1", 3.0))
t.start()

time.sleep(0.2)  # command now in flight
_last_activity["t1"] = time.time() - 2.0  # simulate last activity 2s ago

# Reaper with lifetime=1s: the command has 2.8s left but looks idle.
_cleanup_inactive_envs(lifetime_seconds=1)

t.join()

if env.cleaned_up:
    print("IDLE_REAPER_TORE_DOWN_INFLIGHT_FOREGROUND")
    raise SystemExit(0)
else:
    print("IDLE_REAPER_PRESERVED_INFLIGHT_FOREGROUND")
    raise SystemExit(0)
PY
