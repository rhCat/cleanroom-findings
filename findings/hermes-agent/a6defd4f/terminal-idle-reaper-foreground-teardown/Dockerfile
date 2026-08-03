FROM python:3.12-slim

# Cleanroom for hermes-agent PR #77589 — idle reaper tears down in-flight
# foreground commands (tools/terminal_tool.py::_cleanup_inactive_envs).
# Stock (RED) probe prints IDLE_REAPER_TORE_DOWN_INFLIGHT_FOREGROUND.
# The fix (probe_fix.sh, _foreground_task_ids refresh) prints
# IDLE_REAPER_PRESERVED_INFLIGHT_FOREGROUND.
#
# Build:  docker build -t hermes-agent-idle-reaper .
# Run:    docker run --rm hermes-agent-idle-reaper        # RED signature
#         docker run --rm hermes-agent-idle-reaper fix    # GREEN signature

COPY probe.sh /repro/probe.sh
COPY probe_fix.sh /repro/probe_fix.sh
WORKDIR /repro
ENTRYPOINT ["/bin/sh"]
CMD ["probe.sh"]
