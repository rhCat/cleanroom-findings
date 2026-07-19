# Patch Cleanroom Status

**Status**: VERIFIED — patch applies cleanly and produces correct behavior
**Date**: 2026-07-18
**Patch target**: `src/tool_cb_hdr.c` — `save_etag()` write return-value check
**curl version tested**: 8.19.0 (release tarball, built from source)

## Verified Behavior

- `save_etag_writecheck.patch` applies via `patch -p1` without errors (build asserts the
  new `etag write failed` comment is present in the source).
- Build completes; curl 8.19.0 with the fix runs in the cleanroom.
- Happy path (writable etag file): etag saved (17 bytes), curl exit 0 — **unchanged**.
- Write failure (`RLIMIT_FSIZE=0`): `curl: (23) client returned ERROR on write of 24 bytes`,
  curl **exit 23** — the failure is now surfaced.
- Emits `PASS (PATCHED)`.

## The Patch

```diff
-      fwrite(etag_h, 1, etag_length, etag_save->stream);
-      /* terminate with newline */
-      fputc('\n', etag_save->stream);
-      (void)fflush(etag_save->stream);
+      /* a failed etag write must surface, not be silently discarded */
+      if(fwrite(etag_h, 1, etag_length, etag_save->stream) != etag_length ||
+         /* terminate with newline */
+         fputc('\n', etag_save->stream) == EOF ||
+         fflush(etag_save->stream)) {
+        return CURL_WRITEFUNC_ERROR; /* etag write failed */
+      }
```

Minimal and parallel to the existing `ftruncate`/`fseek` check in the same function: a failed
etag write returns `CURL_WRITEFUNC_ERROR`, exactly as a failed truncate already does.

## Bug Cleanroom

`../curl-etag-save-write-discard/` — stock 8.19.0, same scenario, emits `CONTRADICTION`.
