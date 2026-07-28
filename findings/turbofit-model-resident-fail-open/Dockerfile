# syntax=docker/dockerfile:1
# Bug cleanroom: turbofit _model_is_resident fail-open (unload verification reports false success)
#
# Stock, UNMODIFIED turbohaul_client.py vendored verbatim from
# SouthpawIN/turbofit @ a6326c3d17aa11be7349196397af17e9b16b9079 (sha256 ec95154d…) — no source
# change. _model_is_resident() returns False for every status shape it does not recognise, and its
# only caller is the unload-VERIFICATION loop (turbohaul_client.py:151-160), which reads False as
# "the model has been unloaded" and returns success.
#
# The CONTRADICTION: the model is still resident in every drifted case, yet the verification
# returns success on the FIRST poll — and the TurbohaulClientError timeout that exists to catch
# exactly this becomes unreachable. The controller then believes VRAM was freed when it was not.
#
# Stdlib only, no network. See the patch cleanroom:
#   findings/turbofit-model-resident-fail-open-patch/
FROM python:3.12-slim
WORKDIR /repro
COPY turbohaul_client.py probe.py ./
CMD ["/bin/sh", "-c", "echo 'module under test:' && sha256sum turbohaul_client.py && echo && python3 probe.py"]
