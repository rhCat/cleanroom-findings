#!/bin/sh
# Chamber for PR #77588 / issue #77538 — strengthened GREEN build.
# Fix: /resume and /branch call _transition_context_engine_session, which
# runs the FULL lifecycle: on_session_end(old) then on_session_start(new).

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
        # The buggy path calls this WITHOUT transition metadata.
        pass

    def _transition_context_engine_session(self, new_session_id,
                                           carry_over_context=False):
        # Host helper (run_agent.py:652): full lifecycle with metadata.
        self.engine.on_session_end(self.session_id)
        self.engine.on_session_start(new_session_id,
                                     carry_over_context=carry_over_context)
        self.session_id = new_session_id

def _handle_resume_command(agent, new_session_id):
    # FIX (PR #77588): transition the engine with carry_over_context=False.
    agent.reset_session_state()
    agent._transition_context_engine_session(
        new_session_id, carry_over_context=False
    )

def _handle_branch_command(agent, new_session_id):
    agent.reset_session_state()
    agent._transition_context_engine_session(
        new_session_id, carry_over_context=False
    )

agent = Agent()
_handle_resume_command(agent, "new-session")

hooks = agent.engine.hook_log
full_lifecycle = hooks == ["end:old-session", "start:new-session"]

if agent.engine.bound_session_id != "new-session":
    print("CONTEXT_ENGINE_STUCK_ON_OLD_SESSION")
    raise SystemExit(0)
elif not full_lifecycle:
    # Issue-level contract: on_session_end(old) AND on_session_start(new).
    print("CONTEXT_ENGINE_PARTIAL_LIFECYCLE")
    raise SystemExit(0)
else:
    print("CONTEXT_ENGINE_TRANSITIONED")
    raise SystemExit(0)
PY
