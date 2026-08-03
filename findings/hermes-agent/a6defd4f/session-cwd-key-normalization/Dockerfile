FROM python:3.12-slim

# Cleanroom for hermes-agent PR #77585 — session-cwd key normalization leak
# (tools/terminal_tool.py::clear_session_cwd pops raw key, missing "default").
# Stock (RED) probe prints CWD_STALE_RECORD_SURVIVES.
# The fix (probe_fix.sh, normalized pop) prints CWD_RECORD_CLEARED.
#
# Build:  docker build -t hermes-agent-cwd-normalize .
# Run:    docker run --rm hermes-agent-cwd-normalize         # RED signature
#         docker run --rm hermes-agent-cwd-normalize probe_fix.sh  # GREEN

COPY probe.sh /repro/probe.sh
COPY probe_fix.sh /repro/probe_fix.sh
WORKDIR /repro
ENTRYPOINT ["/bin/sh"]
CMD ["probe.sh"]
