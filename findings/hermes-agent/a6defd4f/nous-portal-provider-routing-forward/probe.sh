#!/bin/sh
# Chamber for PR #77593 / issue #77564 — RED build.
# Stock: build_extra_body copies OpenRouter behavior UNCONDITIONALLY —
# provider_preferences forwarded as body["provider"] (issue #77564: every
# request to a Nous Portal model fails with HTTP 400).

python3 - <<'PY'
def nous_portal_tags(session_id=None):
    return {"hermes_session": session_id or "default"}

def build_extra_body(*, session_id=None, **context):
    # Stock (RED): copied OpenRouter behavior — unconditional forward.
    body = {"tags": nous_portal_tags(session_id=session_id)}
    provider_preferences = context.get("provider_preferences")
    if provider_preferences:
        body["provider"] = provider_preferences  # BUG: Portal 400s on this
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

if not accepted:
    print("NOUS_PORTAL_REJECTED_PROVIDER_ROUTING")
    raise SystemExit(0)
else:
    print("NOUS_PORTAL_ACCEPTED_REQUEST")
    raise SystemExit(0)
PY
