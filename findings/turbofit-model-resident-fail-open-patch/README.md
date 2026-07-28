# turbofit — `_model_is_resident` fails CLOSED on an unreadable status (patch cleanroom)

`docker build -t turbofit-model-resident-fail-open-patch . && docker run --rm turbofit-model-resident-fail-open-patch`

Stdlib only, no network, read-only. `RUN_LOG.txt` is the recorded output.

## The change

`model_resident_fail_closed.patch`, one branch of `_model_is_resident()`:

- an empty or non-matching `residents` **list** is still a PROVEN absence → `False`
- anything that cannot be **read** — missing key, wrong type, or a well-typed list whose entries
  carry none of `("model_tag","model","name","tag")` → `True`, so the caller's timeout fires

The happy path, and the genuine-unload path turbofit's own tests drive, are untouched.

## Result

`0/5` misread (was `5/5`). Every drifted shape now raises `TurbohaulClientError` after the full
poll window instead of returning success on poll 1. The regression control — a genuine unload —
still completes.

## What the cleanroom caught that inspection did not

The first version of this patch treated any well-typed list as readable. It left **1 of 5 still
failing open** (`residents: [{"id": "main"}]`) — the list has the right type, so the predicate
answered "proven absence" from entries it could not actually compare. GREEN failed and named it.
RED-before-GREEN is what made that visible; the fix reads obviously-correct either way.
