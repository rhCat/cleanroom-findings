# Patch Cleanroom Status

**Status**: VERIFIED — 0/5 misread, regression control preserved
**Date**: 2026-07-28
**Patch**: `model_resident_fail_closed.patch` — one branch in `_model_is_resident()`

## Verified Behavior

| case (model STILL resident) | stock | patched |
|---|---|---|
| empty status (transport degraded) | RETURNED-SUCCESS after 1 poll | raises `TurbohaulClientError` |
| `residents` as dict, not list | RETURNED-SUCCESS after 1 poll | raises `TurbohaulClientError` |
| key renamed `residents`→`loaded` | RETURNED-SUCCESS after 1 poll | raises `TurbohaulClientError` |
| entry keyed `id` | RETURNED-SUCCESS after 1 poll | raises `TurbohaulClientError` |
| `active` nested under `data/` | RETURNED-SUCCESS after 1 poll | raises `TurbohaulClientError` |
| **genuine unload (regression control)** | **success** | **success — unchanged** |

## The fix, and what it deliberately does NOT change

An empty or non-matching `residents` **list** remains a PROVEN absence → `False`. Only shapes
that cannot be *read* return `True`: a missing key, a wrong type, or a well-typed list whose
entries carry none of `("model_tag","model","name","tag")`.

That last clause was found by this cleanroom, not by inspection. The first attempt at the fix
treated any well-typed list as readable and left **1 of 5 still failing open**
(`residents: [{"id": "main"}]`) — GREEN failed and exposed it. A correctly-typed list of
unrecognisable entries is still an unreadable status.

## Regression control

`{"active": None, "residents": []}` — the exact shape `tests/test_turbohaul_client.py` drives —
must stay `False` and complete. A fix that failed closed there would hang every real unload to
timeout: a worse bug than the one under test. Verified in BOTH phases.
