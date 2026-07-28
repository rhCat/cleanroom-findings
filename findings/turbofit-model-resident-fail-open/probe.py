"""Cleanroom probe: is _model_is_resident fail-open, in turbofit's REAL source?

Nothing here paraphrases the implementation — turbohaul_client.py is vendored VERBATIM from
SouthpawIN/turbofit@a6326c3d and imported. The probe only supplies inputs and drives the loop.
Read-only: no writes, no network, no mutation of anything.
"""
import time
import turbohaul_client as T

MODEL = "main"
RESIDENT = {"active": {"model_tag": MODEL}, "residents": [{"model_tag": MODEL}]}

# Shapes a real Turbohaul could return while the model is STILL LOADED.
DRIFTED = [
    ("empty status (transport degraded)",        {}),
    ("residents as dict, not list",              {"residents": {"0": {"model_tag": MODEL}}}),
    ("key renamed residents -> loaded",          {"loaded": [{"model_tag": MODEL}]}),
    ("entry keyed 'id' (outside the 4 tried)",   {"residents": [{"id": MODEL}]}),
    ("active nested under data/",                {"data": {"active": {"model_tag": MODEL}}}),
]

print("== control: a well-formed RESIDENT status ==")
ctrl = T._model_is_resident(RESIDENT, MODEL)
print(f"   _model_is_resident(resident)      -> {ctrl}   (expected True)")

print("\n== drifted shapes, model STILL RESIDENT in every one ==")
misread = 0
for label, status in DRIFTED:
    got = T._model_is_resident(status, MODEL)
    if got is False:
        misread += 1
    print(f"   {label:42} -> {got}")

print(f"\n   misread as 'not resident': {misread}/{len(DRIFTED)}")


class _StillLoaded:
    """A Turbohaul that never unloads and reports a drifted status shape."""
    def __init__(self, status):
        self._status = status
        self.polls = 0

    def status(self):
        self.polls += 1
        return self._status


# Drive the REAL verification loop body (turbohaul_client.py:151-160) against a server that
# has NOT unloaded. Transcribing only the loop's control flow; the predicate under test is
# the imported original.
def verify_unloaded(client, model, timeout_s=2.0, poll_interval_s=0.05):
    deadline = time.monotonic() + timeout_s
    while True:
        status = client.status()
        if not T._model_is_resident(status, model):
            return ("RETURNED-SUCCESS", status)
        if time.monotonic() >= deadline:
            raise T.TurbohaulClientError(
                f"Turbohaul did not unload model {model!r} within {timeout_s:g}s")
        time.sleep(poll_interval_s)


# REGRESSION CONTROL. The genuine unload — exactly the shape turbofit's own
# tests/test_turbohaul_client.py drives: active None, residents []. This MUST stay False, and the
# loop MUST return success. A fix that fails closed here would hang every real unload to timeout,
# which is a worse bug than the one under test.
UNLOADED = {"queue": {"depth": 0}, "active": None, "residents": []}
print("\n== regression control: a GENUINE unload (turbofit's own test shape) ==")
gone = T._model_is_resident(UNLOADED, MODEL)
print(f"   _model_is_resident(unloaded)      -> {gone}   (must be False)")
if gone:
    print("       REGRESSION: a real unload is no longer recognised")

print("\n== the unload-verification loop, server has NOT unloaded ==")
# (label, status, still_resident) — FAIL-OPEN is only meaningful where the model IS still
# loaded. The genuine-unload row must return success; flagging that would be the probe lying.
CASES = ([("well-formed, still resident", RESIDENT, True),
          ("GENUINE unload (must succeed)", UNLOADED, False)]
         + [(l, st, True) for l, st in DRIFTED])
fail_open = 0
regression_broken = False
for label, status, still_resident in CASES:
    c = _StillLoaded(status)
    try:
        verdict, _ = verify_unloaded(c, MODEL)
    except T.TurbohaulClientError as exc:
        verdict = f"raised TurbohaulClientError after {c.polls} polls"
    print(f"   {label:42} -> {verdict}")
    if verdict == "RETURNED-SUCCESS" and still_resident:
        fail_open += 1
        print(f"       FAIL-OPEN: reported unloaded after {c.polls} poll(s) "
              f"while the model is still resident")
    if verdict != "RETURNED-SUCCESS" and not still_resident:
        regression_broken = True
        print("       REGRESSION: a genuine unload no longer completes")

# ── verdict, DERIVED from behaviour (both cleanrooms ship the same probe) ──────────────────
# run_all.sh classifies on a line starting at column 0.
print()
if regression_broken:
    print("NOT_CONFIRMED — a genuine unload no longer completes; the fix is worse than the bug")
elif fail_open:
    print(f"CONTRADICTION — {fail_open}/{len(DRIFTED)} drifted status shapes reported the model "
          f"UNLOADED while it is still resident, on the first poll; the TurbohaulClientError "
          f"timeout is unreachable")
else:
    print(f"PASS — 0/{len(DRIFTED)} misread; every unreadable status now times out and raises, "
          f"and the genuine unload still completes")
