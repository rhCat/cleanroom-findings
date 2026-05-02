# Patch Cleanroom Status

**Status**: VERIFIED — patch applies cleanly and error propagation is confirmed  
**Date**: 2026-05-02  
**Patch target**: `merge-ort.c` — `detect_regular_renames` -1 return + caller check  
**Git version tested**: 2.43.7 (Alpine 3.19)

## Verified Behavior

- Patch applies via Python to `merge-ort.c` without errors
- Build completes (~15s)
- Normal merge: rename/rename conflict still detected (no regression)
- Error path: `GIT_TEST_RENAME_DISCARD=1` triggers -1 return → merge exits 2 (clean abort)
- No wrong tree committed in the error case

## Limitations

The patch wires the error path but `diffcore_rename_extended` itself does not yet
return errors. A companion patch to `diffcore.c` / `diffcore-rename.c` is needed
to complete the fix. This patch is preparatory: it ensures the propagation path
exists so that when `diffcore_rename_extended` gains error signaling, it will work
correctly end-to-end.

## Next Steps

- [ ] Investigate `diffcore_rename_extended` internals for failable paths
- [ ] Format as proper `git send-email` patch series (2 patches: this + diffcore)
- [ ] Thread: git@vger.kernel.org, Cc: merge-ort maintainer (Elijah Newren)
- [ ] Reference bug cleanroom structural analysis in cover letter
