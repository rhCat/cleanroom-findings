# hermes-agent — Nous Portal provider_routing forward → HTTP 400

Upstream: **NousResearch/hermes-agent** @ `a6defd4f1549da3fe1d08d6f746fc645c64543f0`
PR: **#77593** (fixes issue **#77564**) — "fix(providers): stop forwarding provider_routing prefs to Nous Portal"

`docker build -t hermes-agent-portal-routing . && docker run --rm hermes-agent-portal-routing`

Stdlib only, no network. Verdict: RED reproduced + GREEN removed (`ok: true` both phases).

## The code

`plugins/model-providers/nous/__init__.py:46-48` (stock, unmodified):

```python
provider_preferences = context.get("provider_preferences")
if provider_preferences:
    body["provider"] = provider_preferences   # <-- Nous Portal 400s on this
```

The Nous profile copied the OpenRouter behavior of forwarding caller-supplied
routing preferences into the request body as `provider`. The Nous Portal
inference endpoint rejects the field:

```
HTTP 400: This endpoint does not honor caller-supplied provider routing
preferences (e.g. only, ignore, order, data_collection, zdr, require_parameters,
sort). Routing is decided centrally per model...
```

The non-profile transport path (`agent/transports/chat_completions.py:444-445`)
already gates this behind `is_openrouter`; the profile was inconsistent with the
transport it rides on. With `provider_routing` in config.yaml, **every** request
to a Nous Portal model fails.

## The asymmetry

OpenRouter honors caller routing prefs; the Portal decides routing centrally.
One `build_extra_body` copied the other's contract. The rose plane has 0 egress
hits for `provider_preferences` — the leak is a **dict-key write**
(`body["provider"] = …`), which the value-flow tracker does not follow.

## Cleanroom evidence

- RED (stock): `NOUS_PORTAL_REJECTED_PROVIDER_ROUTING` — body carries `provider`
  prefs; simulated Portal endpoint rejects.
- GREEN (fix: prefs not forwarded; `tags` field preserved):
  `NOUS_PORTAL_ACCEPTED_REQUEST`.
- `verdict.json`: `ok: true` (red + green).
