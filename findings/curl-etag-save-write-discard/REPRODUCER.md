# Reproducer — curl `--etag-save` silent write failure

Both cleanrooms build curl **8.19.0 from the release tarball** on Alpine 3.20. The bug
cleanroom builds it **stock**; the patch cleanroom applies `save_etag_writecheck.patch`
first. Same version, same scenario — they differ only by the patch.

## Bug cleanroom — stock 8.19.0 → `CONTRADICTION`

```
docker build -t cleanroom-curl-etag-bug findings/curl-etag-save-write-discard
docker run --rm cleanroom-curl-etag-bug
```

Verified output (2026-07-18):

```
$ docker run --rm cleanroom-curl-etag-bug
================================================================
  CURL BUG: --etag-save write failure silently discarded
            save_etag() checks ftruncate but not fwrite/fputc
  Cleanroom — stock unmodified curl 8.19.0 (aarch64-unknown-linux-musl) libcurl/8.19.0
================================================================

── CONTROL (writable etag file) ─────────────────────────────────────────

$ curl --etag-save /tmp/etag.ctrl http://127.0.0.1:8080/
  server sent ETag: yes | curl exit: 0 | etag file size: 17

── BUG (etag file writes fail — RLIMIT_FSIZE=0, ENOSPC/EFBIG class) ──────

$ ( ulimit -f 0; curl --etag-save /tmp/etag.out http://127.0.0.1:8080/ )
  curl exit: 0 | etag file size: 0

────────────────────────────────────────────────────────────────────────

── CONCLUSION ───────────────────────────────────────────────────────────

  CONTROL : server sent ETag, curl exit 0, etag saved (17 bytes)
  BUG     : same server + transfer, etag write fails, curl exit 0,
            etag file EMPTY (0 bytes)

  save_etag() (src/tool_cb_hdr.c) returns CURL_WRITEFUNC_ERROR when
  ftruncate() fails, but ignores fwrite()/fputc() and (void)-casts
  fflush(). A --etag-save target on a full disk is truncated to 0 and
  left empty while curl reports success. The next --etag-compare run
  reads an empty tag and silently loses cache validation.

────────────────────────────────────────────────────────────────────────

CONTRADICTION: server sent an ETag and curl exited 0, but the --etag-save file is empty -- write failure in save_etag() silently discarded (src/tool_cb_hdr.c fwrite/fputc unchecked)
```

## Patch cleanroom — patched 8.19.0 → `PASS`

```
docker build -t cleanroom-curl-etag-patch findings/curl-etag-save-write-discard-patch
docker run --rm cleanroom-curl-etag-patch
```

Verified output (2026-07-18):

```
$ docker run --rm cleanroom-curl-etag-patch
================================================================
  CURL PATCH: --etag-save write failure now surfaced
              save_etag() checks fwrite/fputc/fflush
  Patch cleanroom — curl 8.19.0 (aarch64-unknown-linux-musl) libcurl/8.19.0 built with fix
================================================================

── HAPPY PATH (writable etag file must still work) ───────────────────────

  server sent ETag: yes | curl exit: 0 | etag file size: 17

── WRITE FAILURE (RLIMIT_FSIZE=0) — must now surface, not silently pass ──

curl: (23) client returned ERROR on write of 24 bytes
  curl exit: 23 | etag file size: 0

────────────────────────────────────────────────────────────────────────

── CONCLUSION ───────────────────────────────────────────────────────────

  HAPPY PATH  : etag saved (17 bytes), curl exit 0 — unchanged
  WRITE FAIL  : curl exit 23 (non-zero) — failure SURFACED

  With the patch, save_etag() checks fwrite()/fputc()/fflush() and
  returns CURL_WRITEFUNC_ERROR on a short write, so curl aborts the
  transfer with a write error (exit 23) instead of reporting success
  over a truncated etag file. The happy path is untouched.

────────────────────────────────────────────────────────────────────────

PASS (PATCHED): etag write failure now exits 23 (non-zero); happy path still saves and exits 0 -- patch verified
```

## The failure injection

`RLIMIT_FSIZE=0` (`ulimit -f 0`) caps every regular file at 0 bytes: a write that would
extend the etag file returns `EFBIG` and raises `SIGXFSZ`, which the subshell ignores
(`trap "" XFSZ`) so curl sees the plain write error — the same class of failure as a full
disk (`ENOSPC`) or an I/O error (`EIO`). The control transfer, writing to an unconstrained
file, proves the ETag arrives and saves normally; only the constrained write fails.
