# syntax=docker/dockerfile:1
# Bug cleanroom: curl --etag-save silent write failure (save_etag return-path asymmetry)
#
# Stock, UNMODIFIED curl 8.19.0 built from the release tarball (no source change).
# save_etag() in src/tool_cb_hdr.c checks ftruncate() and returns CURL_WRITEFUNC_ERROR
# on failure, but the subsequent fwrite()/fputc() are unchecked and fflush() is
# explicitly (void)-cast. A regular etag file whose writes fail (disk-full class,
# modeled here with RLIMIT_FSIZE=0) is left empty/partial while curl exits 0.
#
# The CONTRADICTION: the server sent an ETag and curl exited 0, but the etag file
# is empty — a subsequent --etag-compare run silently loses cache validation.
#
# See the patch cleanroom: findings/curl-etag-save-write-discard-patch/

FROM alpine:3.20 AS builder
RUN apk add --no-cache build-base curl tar ca-certificates && update-ca-certificates
ARG CURL_VER=8.19.0
RUN mkdir -p /usr/src \
    && curl -fsSL -o /tmp/curl.tar.gz \
      https://curl.se/download/curl-${CURL_VER}.tar.gz \
       && tar -xz -C /usr/src -f /tmp/curl.tar.gz \
    && mv /usr/src/curl-${CURL_VER} /usr/src/curl
WORKDIR /usr/src/curl
# Minimal build — only HTTP over loopback is needed to exercise --etag-save.
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
echo "  CURL BUG: --etag-save write failure silently discarded"
echo "            save_etag() checks ftruncate but not fwrite/fputc"
echo "  Cleanroom — stock unmodified $(curl --version | head -1)"
echo "================================================================"
echo ""

serve() {  # one-shot HTTP/1.0 server that emits an ETag header
  printf 'HTTP/1.0 200 OK\r\nETag: "cleanroom-demo"\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok' \
    | nc -l -p 8080 >/dev/null 2>&1 &
  sleep 1
}

echo "── CONTROL (writable etag file) ─────────────────────────────────────────"
echo ""
serve
echo '$ curl --etag-save /tmp/etag.ctrl http://127.0.0.1:8080/'
curl -sS -o /dev/null -D /tmp/hdrs --etag-save /tmp/etag.ctrl http://127.0.0.1:8080/
CTRL_RC=$?
SENT_ETAG=no; grep -qi '^etag:' /tmp/hdrs && SENT_ETAG=yes
CTRL_SIZE=$(wc -c < /tmp/etag.ctrl 2>/dev/null || echo 0)
echo "  server sent ETag: $SENT_ETAG | curl exit: $CTRL_RC | etag file size: $CTRL_SIZE"
echo ""

echo "── BUG (etag file writes fail — RLIMIT_FSIZE=0, ENOSPC/EFBIG class) ──────"
echo ""
: > /tmp/etag.out
serve
echo '$ ( ulimit -f 0; curl --etag-save /tmp/etag.out http://127.0.0.1:8080/ )'
( trap "" XFSZ; ulimit -f 0; exec curl -sS -o /dev/null --etag-save /tmp/etag.out http://127.0.0.1:8080/ )
BUG_RC=$?
BUG_SIZE=$(wc -c < /tmp/etag.out 2>/dev/null || echo 0)
echo "  curl exit: $BUG_RC | etag file size: $BUG_SIZE"
echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo ""

echo "── CONCLUSION ───────────────────────────────────────────────────────────"
if [ "$SENT_ETAG" = yes ] && [ "$CTRL_RC" -eq 0 ] && [ "$CTRL_SIZE" -gt 0 ] \
   && [ "$BUG_RC" -eq 0 ] && [ "$BUG_SIZE" -eq 0 ]; then
  echo ""
  echo "  CONTROL : server sent ETag, curl exit 0, etag saved ($CTRL_SIZE bytes)"
  echo "  BUG     : same server + transfer, etag write fails, curl exit 0,"
  echo "            etag file EMPTY ($BUG_SIZE bytes)"
  echo ""
  echo "  save_etag() (src/tool_cb_hdr.c) returns CURL_WRITEFUNC_ERROR when"
  echo "  ftruncate() fails, but ignores fwrite()/fputc() and (void)-casts"
  echo "  fflush(). A --etag-save target on a full disk is truncated to 0 and"
  echo "  left empty while curl reports success. The next --etag-compare run"
  echo "  reads an empty tag and silently loses cache validation."
  echo ""
  echo "────────────────────────────────────────────────────────────────────────"
  echo ""
  echo "CONTRADICTION: server sent an ETag and curl exited 0, but the --etag-save file is empty -- write failure in save_etag() silently discarded (src/tool_cb_hdr.c fwrite/fputc unchecked)"
  exit 0
else
  echo "  NOT_CONFIRMED: sent_etag=$SENT_ETAG ctrl_rc=$CTRL_RC ctrl_size=$CTRL_SIZE bug_rc=$BUG_RC bug_size=$BUG_SIZE"
  echo "────────────────────────────────────────────────────────────────────────"
  echo "NOT_CONFIRMED"
  exit 1
fi
SHEOF

CMD ["bash", "/test.sh"]
