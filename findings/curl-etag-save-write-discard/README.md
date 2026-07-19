# Finding: curl `--etag-save` silent write failure (save_etag return-path asymmetry)

**Severity**: Low-Medium
**Component**: `src/tool_cb_hdr.c` — the curl tool's `--etag-save` header callback
**Affected function**: `save_etag`
**curl version tested**: 8.19.0 (release tarball, built from source in the cleanroom)
**Also present at**: `master` @ `1128177a` (the analyzed commit) and shipped 8.14.1 (etag write inline in `tool_header_cb`)
**Detector**: alembic / transmutation `ErrorPropagation` → ABSORB(fwrite) — governed run 2026-07-18

---

## Structural Description

`save_etag()` writes the server's `ETag` value to the `--etag-save` file. Its return-value
contract is **asymmetric within the one function**:

| Operation | Failure checked? | On failure |
|-----------|------------------|------------|
| `ftruncate(fileno(stream), 0)` (or `fseek`) | **yes** | `return CURL_WRITEFUNC_ERROR` |
| `fwrite(etag_h, 1, etag_length, stream)` | **NO** | ignored |
| `fputc('\n', stream)` | **NO** | ignored |
| `fflush(stream)` | **NO** | explicitly `(void)`-cast |

The function guards the *truncate* — which prepares the file — but not the *writes* that
actually put the etag on disk. A write failure after a successful truncate leaves the file
**empty or partially written**, and `save_etag` returns `0` ("ok"). The caller in
`tool_header_cb` (`if(rc) return rc;`) therefore sees success.

```c
static size_t save_etag(const char *etag_h, const char *endp,
                        struct OutStruct *etag_save)
{
  ...
      if(ftruncate(fileno(etag_save->stream), 0)) {   /* checked */
        return CURL_WRITEFUNC_ERROR;
      }

      fwrite(etag_h, 1, etag_length, etag_save->stream);   /* unchecked */
      fputc('\n', etag_save->stream);                      /* unchecked */
      (void)fflush(etag_save->stream);                     /* discarded */
  ...
  return 0; /* ok */
}
```

## Silent Failure Mode

```
server sends ETag → save_etag() → ftruncate to 0    → OK
                                → fwrite etag        → FAIL (ENOSPC / EFBIG / EIO)
                                → return 0           ← caller sees SUCCESS, curl exits 0
```

The etag file is now empty, but curl reported success. The failure is invisible: no error,
no non-zero exit, no diagnostic.

## Why it matters

`--etag-save` exists to be paired with `--etag-compare` on a later run: curl sends the saved
tag as `If-None-Match`, and the server answers `304 Not Modified` to skip an unchanged
download. If the save silently produced an **empty** file:

- the next `--etag-compare` run sends no (or an empty) validator,
- the conditional-GET optimization silently breaks — every run re-downloads, or worse, a
  scripted cache treats the empty tag as "no cached copy,"
- and nothing in the first run's exit status or output warned the user.

This is a robustness bug, not a security vulnerability: it requires a write failure on the
etag file (a full disk, a quota, an I/O error, a `RLIMIT_FSIZE` cap). But curl already treats
the *truncate* failure of the same file as fatal (`CURL_WRITEFUNC_ERROR`) — the write failure
should be treated the same way. The asymmetry is the defect.

## Reproduction

`Dockerfile` builds stock, unmodified curl 8.19.0 from the release tarball and runs two
transfers against the same one-shot local server:

1. **control** — a writable etag file: server sends ETag, curl exits 0, etag saved (17 bytes).
2. **bug** — the identical transfer with the etag file's writes failing (`RLIMIT_FSIZE=0`,
   `SIGXFSZ` ignored → every write returns `EFBIG`, the disk-full class): curl **exits 0** and
   the etag file is left **empty (0 bytes)**.

```
docker build -t cleanroom-curl-etag-bug findings/curl-etag-save-write-discard
docker run --rm cleanroom-curl-etag-bug
```

Emits `CONTRADICTION`. See `REPRODUCER.md` for the exact output and `PATCH.diff` for the fix
(verified in the paired patch cleanroom `curl-etag-save-write-discard-patch/`, which emits
`PASS`).

## Provenance

Surfaced by a governed transmutation run over curl `master` @ `1128177a` on 2026-07-18: the
mechanical claim `ABSORB(fwrite)` at `src/tool_cb_hdr.c:276`, `save_etag`
(`grounding: error_propagation_absorb`). Adjudicated against source, reproduced in a governed
`magnumopus:cleanroom` red/green run, then hardened into this standalone cleanroom on the
shipped 8.19.0 release. See `DETECTOR_OUTPUT.json`.
