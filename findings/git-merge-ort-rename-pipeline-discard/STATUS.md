# Submission Status

**Status**: DRAFT — structural gap documented, no wild reproducer, patch cleanroom verified  
**Date drafted**: 2026-05-02  
**Finding method**: alembic Phase 6.1 C unified-vocab (c-typestate-extractor) + CFG symmetry

## Timeline

- 2026-05-02: Finding identified via FlowAsymmetry + ErrorPropagation detectors on git corpus
- 2026-05-02: Cross-lens analysis confirmed (unified-vocab CHECK=16/BORROW=71 on detect_and_process_renames)
- 2026-05-02: Structural gap documented (no wild reproducer — see below)
- 2026-05-02: Patch cleanroom separated per SOP:
  - `findings/git-merge-ort-rename-pipeline-discard-patch/`
  - Verified: PASS (PATCHED) confirmed

## No Wild Reproducer

`detect_regular_renames` has no production error paths. `diffcore_rename_extended`
does not return errors. The structural gap exists but cannot be triggered on stock
unmodified git without a failable internal path in rename detection.

**This cleanroom is documentation-only.** It records the structural gap for
upstream defensive-coding review. The patch cleanroom separately verifies the fix.

## CVE Assessment

Probably **not CVE-worthy** — requires specific failure conditions (OOM, object
store degradation) to trigger in production. Not directly exploitable by an
attacker. However, the merge-queue tree-corruption symptom class is a high-severity
reliability issue for CI/CD systems where the committed tree must match the tested
tree.

## Next Steps

- [ ] Verify exact line numbers against git main branch (HEAD shifts)
- [ ] Identify mailing list thread on merge-ort error handling
- [ ] Check if `diffcore_rename_extended` has any in-progress error signaling work
- [ ] Send patch with `git send-email` format, Cc: merge-ort maintainer (Elijah Newren)
- [ ] Reference prior merge-ort reliability discussions in the cover letter
