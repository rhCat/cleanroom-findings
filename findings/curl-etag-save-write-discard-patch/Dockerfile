# syntax=docker/dockerfile:1
# Patch cleanroom: curl --etag-save silent write failure — fix verified
#
# Builds curl 8.19.0 from the release tarball with the minimal save_etag() write-check
# patch applied, then reruns the exact bug-cleanroom scenario. With the patch, a failed
# etag write returns CURL_WRITEFUNC_ERROR (as ftruncate already does) → curl exits
# non-zero instead of silently leaving an empty etag file.
#
# See the bug cleanroom: findings/curl-etag-save-write-discard/  (stock 8.19.0, CONTRADICTION)

FROM alpine:3.20 AS builder
RUN apk add --no-cache build-base curl tar ca-certificates && update-ca-certificates
ARG CURL_VER=8.19.0
RUN mkdir -p /usr/src \
    && curl -fsSL -o /tmp/curl.tar.gz \
      https://curl.se/download/curl-${CURL_VER}.tar.gz \
       && tar -xz -C /usr/src -f /tmp/curl.tar.gz \
    && mv /usr/src/curl-${CURL_VER} /usr/src/curl
WORKDIR /usr/src/curl

# Apply the proposed patch: check fwrite/fputc/fflush in save_etag() and return
# CURL_WRITEFUNC_ERROR on failure — parallel to the existing ftruncate/fseek check.
COPY save_etag_writecheck.patch /tmp/save_etag_writecheck.patch
RUN patch -p1 < /tmp/save_etag_writecheck.patch \
    && grep -q "etag write failed" src/tool_cb_hdr.c

RUN ./configure --prefix=/opt/curl --without-ssl --disable-shared \
      --without-libpsl --disable-ldap --without-nghttp2 --without-brotli \
      --without-zstd --without-libidn2 --disable-docs --disable-manual \
    && make -j"$(nproc)" && make install

FROM alpine:3.20
RUN apk add --no-cache bash
COPY --from=builder /opt/curl /opt/curl
ENV PATH="/opt/curl/bin:$PATH"

RUN <<'SHEOF' cat > /test.sh
#!/bin/bash
set -uo pipefail

echo "================================================================"
echo "  CURL PATCH: --etag-save write failure now surfaced"
echo "              save_etag() checks fwrite/fputc/fflush"
echo "  Patch cleanroom — $(curl --version | head -1) built with fix"
echo "================================================================"
echo ""

serve() {
  printf 'HTTP/1.0 200 OK\r\nETag: "cleanroom-demo"\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok' \
    | nc -l -p 8080 >/dev/null 2>&1 &
  sleep 1
}

echo "── HAPPY PATH (writable etag file must still work) ───────────────────────"
echo ""
serve
curl -sS -o /dev/null -D /tmp/hdrs --etag-save /tmp/etag.ctrl http://127.0.0.1:8080/
CTRL_RC=$?
CTRL_SIZE=$(wc -c < /tmp/etag.ctrl 2>/dev/null || echo 0)
SENT_ETAG=no; grep -qi '^etag:' /tmp/hdrs && SENT_ETAG=yes
echo "  server sent ETag: $SENT_ETAG | curl exit: $CTRL_RC | etag file size: $CTRL_SIZE"
echo ""

echo "── WRITE FAILURE (RLIMIT_FSIZE=0) — must now surface, not silently pass ──"
echo ""
: > /tmp/etag.out
serve
( trap "" XFSZ; ulimit -f 0; exec curl -sS -o /dev/null --etag-save /tmp/etag.out http://127.0.0.1:8080/ )
FAIL_RC=$?
FAIL_SIZE=$(wc -c < /tmp/etag.out 2>/dev/null || echo 0)
echo "  curl exit: $FAIL_RC | etag file size: $FAIL_SIZE"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

echo "── CONCLUSION ───────────────────────────────────────────────────────────"
if [ "$SENT_ETAG" = yes ] && [ "$CTRL_RC" -eq 0 ] && [ "$CTRL_SIZE" -gt 0 ] \
   && [ "$FAIL_RC" -ne 0 ]; then
  echo ""
  echo "  HAPPY PATH  : etag saved ($CTRL_SIZE bytes), curl exit 0 — unchanged"
  echo "  WRITE FAIL  : curl exit $FAIL_RC (non-zero) — failure SURFACED"
  echo ""
  echo "  With the patch, save_etag() checks fwrite()/fputc()/fflush() and"
  echo "  returns CURL_WRITEFUNC_ERROR on a short write, so curl aborts the"
  echo "  transfer with a write error (exit 23) instead of reporting success"
  echo "  over a truncated etag file. The happy path is untouched."
  echo ""
  echo "────────────────────────────────────────────────────────────────────────"
  echo ""
  echo "PASS (PATCHED): etag write failure now exits $FAIL_RC (non-zero); happy path still saves and exits 0 -- patch verified"
  exit 0
else
  echo "  NOT_CONFIRMED: sent_etag=$SENT_ETAG ctrl_rc=$CTRL_RC ctrl_size=$CTRL_SIZE fail_rc=$FAIL_RC"
  echo "────────────────────────────────────────────────────────────────────────"
  echo "NOT_CONFIRMED: patch may not have applied"
  exit 1
fi
SHEOF

CMD ["bash", "/test.sh"]
