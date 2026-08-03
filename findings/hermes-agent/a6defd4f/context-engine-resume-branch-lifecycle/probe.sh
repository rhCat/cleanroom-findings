#!/bin/sh
# Chamber for PR #77588 / issue #77538 — RED build.
# Stock: /resume calls reset_session_state() WITHOUT transition metadata —
# only the reset half of the ContextEngine lifecycle runs; on_session_start
# never fires and the engine stays bound to the old session (issue #77538).

python3 - <<'PY'
class ContextEngine:
    def __init__(self):
        self.bound_session_id = None
        self.hook_log = []

    def on_session_end(self, session_id):
        self.hook_log.append("end:" + str(session_id))

    def on_session_start(self, session_id, **meta):
        self.hook_log.append("start:" + str(session_id))
        self.bound_session_id = session_id

class Agent:
    def __init__(self):
        self.session_id = "old-session"
        self.engine = ContextEngine()

    def reset_session_state(self):
        # Stock path: runs reset WITHOUT old session id / prior transcript.
        pass

    def _transition_context_engine_session(self, new_session_id,
                                           carry_over_context=False):
        # Host helper exists (run_agent.py:652) but stock /resume never calls it.
        self.engine.on_session_end(self.session_id)
        self.engine.on_session_start(new_session_id,
                                     carry_over_context=carry_over_context)
        self.session_id = new_session_id

def _handle_resume_command(agent, new_session_id):
    # Stock BUG: updates session id + reset_session_state, but never calls
    # _transition_context_engine_session(new_session_id).
    agent.session_id = new_session_id
    agent.reset_session_state()

def _handle_branch_command(agent, new_session_id):
    agent.session_id = new_session_id
    agent.reset_session_state()

agent = Agent()
_handle_resume_command(agent, "new-session")

hooks = agent.engine.hook_log
if agent.engine.bound_session_id != "new-session":
    print("CONTEXT_ENGINE_STUCK_ON_OLD_SESSION")
    raise SystemExit(0)
elif hooks != ["end:old-session", "start:new-session"]:
    print("CONTEXT_ENGINE_PARTIAL_LIFECYCLE")
    raise SystemExit(0)
else:
    print("CONTEXT_ENGINE_TRANSITIONED")
    raise SystemExit(0)
PY
