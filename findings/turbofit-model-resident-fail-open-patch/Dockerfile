# syntax=docker/dockerfile:1
# Patch cleanroom: turbofit _model_is_resident fails CLOSED on an unreadable status
#
# Same module as the bug cleanroom (SouthpawIN/turbofit @ a6326c3d) with
# model_resident_fail_closed.patch applied. The ONLY change is the unreadable-status branch:
#
#   * an empty or non-matching `residents` LIST is still a PROVEN absence  -> False
#   * anything we cannot read — missing key, wrong type, or a well-typed list whose entries carry
#     none of ("model_tag","model","name","tag") — is NOT a proven absence  -> True
#
# so the caller's TurbohaulClientError timeout fires instead of reporting a false unload.
#
# REGRESSION CONTROL: {"active": None, "residents": []} — the exact shape turbofit's own
# tests/test_turbohaul_client.py drives — must still read False and complete. A fix that failed
# closed there would hang every real unload to timeout, a worse bug than the one under test.
#
# Stdlib only, no network. Bug cleanroom: findings/turbofit-model-resident-fail-open/
FROM python:3.12-slim
WORKDIR /repro
COPY turbohaul_client.py probe.py ./
CMD ["/bin/sh", "-c", "echo 'module under test:' && sha256sum turbohaul_client.py && echo && python3 probe.py"]
