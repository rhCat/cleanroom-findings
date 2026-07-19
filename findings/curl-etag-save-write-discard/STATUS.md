# Bug Cleanroom Status

**Status**: CONFIRMED — reproduces on stock curl 8.19.0 (built from source)
**Date**: 2026-07-18
**Target**: `src/tool_cb_hdr.c` — `save_etag()` fwrite/fputc/fflush return values unchecked
**curl version tested**: 8.19.0 (release tarball); also present at master @ 1128177a

## Confirmed Behavior

- Stock, unmodified 8.19.0 builds and runs in the cleanroom.
- Control transfer (writable etag file): server sends ETag, curl exits 0, etag saved (17 bytes).
- Bug transfer (etag writes fail, `RLIMIT_FSIZE=0`): curl **exits 0**, etag file **empty (0 bytes)**.
- Emits `CONTRADICTION`.

## Paired Patch Cleanroom

`../curl-etag-save-write-discard-patch/` — same 8.19.0 with `save_etag_writecheck.patch`
applied: the write failure now exits 23 (`CURL_WRITEFUNC_ERROR`), the happy path still saves
and exits 0. Emits `PASS`. **VERIFIED.**

## Next Steps

- [ ] Format `PATCH.diff` as a `git format-patch` commit with a message referencing the
      ftruncate/write asymmetry.
- [ ] Open a PR against curl/curl (normal GitHub PR channel), disclosing the static-analysis
      origin; link the red/green reproduction. Keep the diff minimal, no pipeline framing.
- [ ] Optional: a gold-standard green that builds patched curl at `master` HEAD (this cleanroom
      already builds from source, so the same patch applies there once rebased on the current
      `save_etag`).
