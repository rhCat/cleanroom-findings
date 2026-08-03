#!/bin/sh
# Chamber for PR #77593 / issue #77564 — strengthened GREEN build.
# Fix: build_extra_body no longer copies OpenRouter behavior for the Portal:
# provider_routing prefs are NOT forwarded as body["provider"], AND the
# Portal tags field survives (nous_portal_tags(session_id=...) still present).

python3 - <<'PY'
def nous_portal_tags(session_id=None):
    # Minimal stand-in for the real helper.
    return {"hermes_session": session_id or "default"}

def build_extra_body(*, session_id=None, **context):
    # FIX (PR #77593): routing decided centrally per model on the Portal.
    body = {"tags": nous_portal_tags(session_id=session_id)}
    # provider_preferences intentionally NOT forwarded to the Portal.
    return body

def portal_endpoint_accepts(body):
    if "provider" in body and isinstance(body.get("provider"), dict):
        return False, "HTTP 400: provider routing not honored"
    return True, "ok"

context = {
    "provider_preferences": {
        "only": ["anthropic"], "sort": ["speed"],
    }
}
body = build_extra_body(session_id="sess-1", **context)

accepted, reason = portal_endpoint_accepts(body)
tags_ok = body.get("tags") == {"hermes_session": "sess-1"}

if not accepted:
    print("NOUS_PORTAL_REJECTED_PROVIDER_ROUTING")
    raise SystemExit(0)
elif not tags_ok:
    # Issue-level contract: tags must survive the fix.
    print("NOUS_PORTAL_TAGS_LOST")
    raise SystemExit(0)
else:
    print("NOUS_PORTAL_ACCEPTED_REQUEST")
    raise SystemExit(0)
PY
