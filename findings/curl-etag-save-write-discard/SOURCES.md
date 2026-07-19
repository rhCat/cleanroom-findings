# Sources — curl `--etag-save` silent write failure

## Upstream code

- `src/tool_cb_hdr.c` — `save_etag()` (the affected function) and its caller in
  `tool_header_cb()` (`if(rc) return rc;`).
  - 8.19.0: https://github.com/curl/curl/blob/curl-8_19_0/src/tool_cb_hdr.c
  - master @ analyzed commit: https://github.com/curl/curl/blob/1128177a6f725d1f8c4cba4f7ff6532969109e7a/src/tool_cb_hdr.c
- The tarball built in both cleanrooms: https://curl.se/download/curl-8.19.0.tar.gz

## Option semantics (why an empty save matters)

- `--etag-save <file>` and `--etag-compare <file>` — curl docs: the saved ETag is replayed as
  `If-None-Match` on a later request so an unchanged resource returns `304 Not Modified`.
  https://curl.se/docs/manpage.html#--etag-save

## Contribution policy (checked 2026-07-18, before drafting)

- curl still accepts pull requests on GitHub and prefers them to mailed patches.
  https://curl.se/dev/contribute.html
- This is a robustness fix submitted through the normal PR channel — **not** a security report
  (the HackerOne bug-bounty channel was closed in Jan 2026; that closure covers security
  submissions, not code contributions).
- Policy on AI-assisted work: acceptable if it meets the normal bar (clear, tested, documented).
  The finding here is human-verified end to end with a red/green reproduction; disclose the
  static-analysis origin plainly, as curl already merges Coverity/clang-tidy-driven fixes.

## This project

- Governed provenance: `DETECTOR_OUTPUT.json` (transmutation run over curl master @ 1128177a).
- Reproduction + fix verification: `REPRODUCER.md`, `PATCH.diff`, and the paired patch
  cleanroom `../curl-etag-save-write-discard-patch/`.
