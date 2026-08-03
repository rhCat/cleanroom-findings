FROM python:3.12-slim

# Cleanroom for hermes-agent PR #77593 / issue #77564 — Nous Portal
# provider_routing forward → HTTP 400 (plugins/model-providers/nous/__init__.py).
# Stock (RED) probe prints NOUS_PORTAL_REJECTED_PROVIDER_ROUTING.
# The fix (probe_fix.sh, prefs stripped + tags preserved) prints
# NOUS_PORTAL_ACCEPTED_REQUEST.
#
# Build:  docker build -t hermes-agent-portal-routing .
# Run:    docker run --rm hermes-agent-portal-routing         # RED signature
#         docker run --rm hermes-agent-portal-routing probe_fix.sh  # GREEN

COPY probe.sh /repro/probe.sh
COPY probe_fix.sh /repro/probe_fix.sh
WORKDIR /repro
ENTRYPOINT ["/bin/sh"]
CMD ["probe.sh"]
