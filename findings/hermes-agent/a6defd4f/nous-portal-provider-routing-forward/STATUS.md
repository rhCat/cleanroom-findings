# Bug Cleanroom Status

**Status**: VERIFIED (RED reproduced + GREEN removed) — cleanroom `magnumopus:cleanroom` verify perk
**Date**: 2026-08-03
**Target**: `plugins/model-providers/nous/__init__.py:46-48` — `build_extra_body()` forwards
`provider_preferences` as `body["provider"]` unconditionally; the Nous Portal endpoint rejects the field
with HTTP 400 (issue #77564: every request fails with `provider_routing` set).
**PR**: https://github.com/NousResearch/hermes-agent/pull/77593
**Issue**: https://github.com/NousResearch/hermes-agent/issues/77564

## Confirmed Behavior

- RED (stock chamber): body carries `provider` routing prefs; simulated Portal
  endpoint rejects → `NOUS_PORTAL_REJECTED_PROVIDER_ROUTING`.
- GREEN (fix chamber: prefs not forwarded, `tags` field preserved —
  issue-level contract): `NOUS_PORTAL_ACCEPTED_REQUEST`.
- `verdict.json`: `{"phases": {"red": {"ok": true}, "green": {"ok": true}}, "ok": true}`
  spec_sha `98709da590649935867688e56ab83c765bbfcb0a0a41e332b95b64d74c16000d`.
