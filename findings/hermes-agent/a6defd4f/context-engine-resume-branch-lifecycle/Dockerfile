FROM python:3.12-slim

# Cleanroom for hermes-agent PR #77588 / issue #77538 — /resume + /branch skip
# the external context-engine session lifecycle (cli_commands_mixin.py).
# Stock (RED) probe prints CONTEXT_ENGINE_STUCK_ON_OLD_SESSION.
# The fix (probe_fix.sh, _transition_context_engine_session after memory
# switch) prints CONTEXT_ENGINE_TRANSITIONED.
#
# Build:  docker build -t hermes-agent-context-engine .
# Run:    docker run --rm hermes-agent-context-engine          # RED signature
#         docker run --rm hermes-agent-context-engine probe_fix.sh  # GREEN

COPY probe.sh /repro/probe.sh
COPY probe_fix.sh /repro/probe_fix.sh
WORKDIR /repro
ENTRYPOINT ["/bin/sh"]
CMD ["probe.sh"]
