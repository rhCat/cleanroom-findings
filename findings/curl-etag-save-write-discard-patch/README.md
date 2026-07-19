# Patch Cleanroom: curl `--etag-save` silent write failure — fix verified

**Status**: VERIFIED
**Target**: `src/tool_cb_hdr.c` — `save_etag()`
**curl version**: 8.19.0 (release tarball, built from source with the patch)

Pairs with the bug cleanroom `../curl-etag-save-write-discard/`. Same curl version, same
scenario; this one applies `save_etag_writecheck.patch` before building.

## What the patch does

`save_etag()` already returns `CURL_WRITEFUNC_ERROR` when `ftruncate()`/`fseek()` fails, but
ignored the `fwrite()`/`fputc()` results and `(void)`-cast `fflush()`. The patch checks all
three and returns `CURL_WRITEFUNC_ERROR` on failure — the same error path the truncate already
uses, so a write failure now aborts the transfer instead of silently leaving an empty etag file.

See `save_etag_writecheck.patch`.

## Run

```
docker build -t cleanroom-curl-etag-patch findings/curl-etag-save-write-discard-patch
docker run --rm cleanroom-curl-etag-patch
```

Emits `PASS (PATCHED)`: the write failure now exits 23; the happy path still saves and exits 0.
Verified output in `STATUS.md`.
