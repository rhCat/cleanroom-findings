# turbofit — `_model_is_resident` fail-open in unload verification

`docker build -t turbofit-model-resident-fail-open . && docker run --rm turbofit-model-resident-fail-open`

Stdlib only, no network, read-only. `RUN_LOG.txt` is the recorded output.

## The code

`src/turbofit_runtime/turbohaul_client.py:217-228` (stock, unmodified):

```python
def _model_is_resident(status: dict[str, Any], model: str) -> bool:
    def matches(value: Any) -> bool:
        if isinstance(value, str):
            return value == model
        if isinstance(value, dict):
            return any(value.get(key) == model for key in ("model_tag", "model", "name", "tag"))
        return False

    if matches(status.get("active")) or matches(status.get("idle_hot")):
        return True
    residents = status.get("residents")
    return isinstance(residents, list) and any(matches(item) for item in residents)
```

Its only caller, `:151-160`:

```python
while True:
    status = self.status()
    if not _model_is_resident(status, model):
        return status                      # <-- declares the model UNLOADED
    if time.monotonic() >= deadline:
        raise TurbohaulClientError(f"Turbohaul did not unload model {model!r} ...")
    time.sleep(poll_interval_s)
```

## The asymmetry

The predicate answers a **two-valued** question — resident or not — over a **three-valued**
input: resident, absent, or *unreadable*. Unreadable collapses into absent.

That collapse would be harmless in a query. Here the caller treats `False` as proof of unload,
so an unreadable status becomes a **false success on the first poll**, and the
`TurbohaulClientError` timeout — the guard written for exactly this failure — can never fire,
because reaching it requires the predicate to keep returning `True`.

In turbofit's own terms ("safely contracts and heals under VRAM pressure"), the controller
proceeds to load the next model believing VRAM was freed.

## Reproduction

Five status shapes, model still resident in every one; all five misread. Full transcript in
`RUN_LOG.txt`; proposed fix in `PATCH.diff` and the paired patch cleanroom.
