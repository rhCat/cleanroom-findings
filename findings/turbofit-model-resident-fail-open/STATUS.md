# Bug Cleanroom Status

**Status**: CONFIRMED — reproduces on stock turbofit @ `a6326c3d` (module vendored verbatim)
**Date**: 2026-07-28
**Target**: `src/turbofit_runtime/turbohaul_client.py:217-228` — `_model_is_resident()` returns
`False` for every status shape it does not recognise
**Caller**: same file, `:151-160` — the unload-VERIFICATION loop, which reads `False` as
"the model has been unloaded" and returns success
**Module sha256**: `ec95154db4710fa32f23082d6bd9daa75c3e5802e5f94bb6885d7c64c6e6ad2c`

## Confirmed Behavior

- Control (well-formed RESIDENT status): `True`, and the loop correctly raises
  `TurbohaulClientError` after 40 polls. **The guard works when the shape is recognised.**
- Regression control (genuine unload — `{"active": None, "residents": []}`, the shape
  turbofit's own `tests/test_turbohaul_client.py` drives): `False`, loop returns success. Correct.
- **5/5 drifted shapes, model still resident in every one, misread as "not resident":**
  empty status; `residents` as a dict; key renamed `residents`→`loaded`; entry keyed `id`;
  `active` nested under `data/`.
- The loop then **returns success on the FIRST poll** in all five, so the
  `TurbohaulClientError` timeout that exists to catch precisely this is **unreachable**.
- Emits `FAIL-OPEN`.

## Why it matters

turbofit's stated purpose is to "safely contract and heal under VRAM pressure". This is the
check that a model actually left VRAM. A false "unloaded" means the controller loads the next
model believing memory was freed. The safety property inverts on the default.

`matches()` trying four different key names (`model_tag`, `model`, `name`, `tag`) is itself
evidence the Turbohaul status schema is not stable across versions — a fifth key silently
reads as absent.

## Scope / limits

This proves the predicate fails open and that the loop consumes it that way. It does **not**
prove a live Turbohaul emits these shapes; the drift set is constructed. Confirming which
drifts are reachable needs the Turbohaul Manager v0.7 API contract.

## Paired Patch Cleanroom

`../turbofit-model-resident-fail-open-patch/` — 0/5 misread, genuine unload preserved.
Emits `PASS`. **VERIFIED.**
