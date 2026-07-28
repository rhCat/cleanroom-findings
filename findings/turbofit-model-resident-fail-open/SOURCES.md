# Sources

| item | value |
|---|---|
| upstream | https://github.com/SouthpawIN/turbofit |
| commit | `a6326c3d17aa11be7349196397af17e9b16b9079` (branch `main`) |
| file | `src/turbofit_runtime/turbohaul_client.py` |
| module sha256 | `ec95154db4710fa32f23082d6bd9daa75c3e5802e5f94bb6885d7c64c6e6ad2c` |
| licence | see upstream `LICENSE` |

`turbohaul_client.py` is vendored **verbatim and unmodified** — the probe imports the real
module and only supplies inputs. `probe.py` transcribes the caller's control flow
(`:151-160`) so the loop can be driven against a stub server; the predicate under test is the
imported original, never a restatement.

Upstream is stdlib-only (`json`, `time`, `dataclasses`, `typing`, `urllib`), so the cleanroom
needs no dependency resolution and no network.
