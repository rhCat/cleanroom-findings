# Status

| Field | Value |
|-------|-------|
| Finding ID | git-update-ref-parse-arg-inconsistency-patch |
| Type | Patch cleanroom |
| Status | VERIFIED |
| Docker build | Passes |
| Test A (regression) | PASS — valid symref-update still works |
| Test B (stock asymmetry) | CONFIRMED — stock git accepts invalid target, late/absent error |
| Test C (patch behavior) | PASS — patched git rejects invalid target at parse time |
| Test D (comparison) | PASS — `update` always rejected early (asymmetry documented) |
| Created | 2026-05-03 |
