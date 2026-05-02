# Submission Status

**Status**: DRAFT — bug confirmed reproducible, patch cleanroom verified  
**Date drafted**: 2026-05-02  
**Finding method**: alembic FlowAsymmetry + ErrorPropagation detectors on git corpus

## Timeline

- 2026-05-02: Finding identified via FlowAsymmetry detector on git v2.49.0
- 2026-05-02: Cross-lens analysis confirmed (vocab asymmetry: abort CHECK=0, prepare CHECK=5)
- 2026-05-02: Bug cleanroom built and verified (CONTRADICTION confirmed)
- 2026-05-02: Patch cleanroom separated per SOP:
  - `findings/git-hook-return-discard-patch/`
  - Verified: PASS (PATCHED) confirmed

## CVE Assessment

Probably **not CVE-worthy** on its own — requires a hook that fails post-commit,
which is an operational condition rather than an attacker-controlled path. However,
the silent-failure semantics create a class of security issues in deployments where
the `committed` phase hook enforces access control, audit logging, or security
notifications. In those deployments, a transient failure silently drops the security
side-effect.

## Next Steps

- [ ] Format as proper `git send-email` patch with commit message
- [ ] Thread: git@vger.kernel.org, Cc: hooks subsystem maintainer
- [ ] Reference bug cleanroom CONTRADICTION output in cover letter
- [ ] Documentation addition: `Documentation/githooks.txt` best-practice note
      that policy enforcement should use `preparing`/`prepared` phases (checked)
      rather than `committed` (non-fatal after this patch)
