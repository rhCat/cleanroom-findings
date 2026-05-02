# cleanroom-findings

Reproducible structural-bug cleanrooms for upstream git submission.

Each finding is a self-contained directory under `findings/` with a bug cleanroom
(stock unmodified code, Docker reproducer or documentation), a patch cleanroom
(Docker reproducer that verifies the fix), and supporting analysis artifacts.

```
docker build -t <name> findings/<name> && docker run --rm <name>
```

Or run everything at once: `./run_all.sh`

---

## Philosophy

### Three Lenses

Bugs are found by analyzing code through three independent lenses. A finding
requires evidence from at least two.

**Topology lens** — coarse control-flow shape: what path does this code follow?

Patterns like `CASCADE` (linear chain of calls with no branching), `DIAMOND`
(branch-merge with asymmetric error handling on each arm), `LOOP` (iteration
with early-exit on one branch but not another). The topology lens flags structural
shapes that have historically correlated with bug classes — it doesn't read semantics,
just graph shape. A `DIAMOND` where one arm checks a return value and the other
doesn't is a `FlowAsymmetry` candidate regardless of what the function does.

**Vocabulary lens** — semantic intent at the gate level: what does each operation
*mean*?

Built using per-language compiler APIs (libclang for C, MIR for Rust, JDT for Java),
not syntactic parsers. Each statement is assigned a gate type from a unified
vocabulary: `CHECK` (branch on a value), `BORROW` (read without modify), `MUTATE`
(write), `COMPUTE` (derive a value), `CONSTRUCT` (allocate/initialize), `RETURN`
(exit the function), `CALL` (invoke another function), and a few others. The ratio
of `CHECK` gates to total gates within a function is a proxy for how carefully it
validates its own logic. A function with `CHECK=0` in an error-recovery path is
suspicious regardless of topology.

**Empirical lens** — structural patterns grounded against a real CVE catalog: what
shapes have actually been exploited in the wild?

Patterns extracted from historical CVEs (unchecked return codes, asymmetric error
branches, NULL deref after partial initialization, integer truncation in size
calculations) are used as detectors. A finding that matches a known-exploited shape
gets higher confidence than one that is merely theoretically wrong.

### Cleanroom Doctrine

Each finding gets **two cleanrooms**, never bundled:

- **Bug cleanroom**: demonstrates the structural gap using stock unmodified code.
  No source injection. No synthetic failure paths. If the bug can be reproduced
  on stock code (a wild reproducer), the Dockerfile does that. If it cannot (a
  structural gap with no current trigger), the cleanroom is documentation-only and
  says so explicitly.

- **Patch cleanroom**: verifies the proposed fix. May use synthetic test hooks
  (e.g., `GIT_TEST_*` environment variables, analogous to git's own test harness)
  to exercise error paths that are structurally wired but have no current production
  trigger. This is patch testing, not a bug reproducer.

The separation is strict because mixing them produces misleading artifacts: a patch
cleanroom that exercises a synthetic error path is not evidence that the bug
manifests on stock code.

Both cleanrooms are Docker containers. Anyone can `docker build && docker run` to
independently verify the bug behavior or the patch behavior without any external
dependencies.

**Minimal patches** — proposed fixes use the lowest-impact mechanism that closes
the structural gap: `warning()` rather than a return-code change when changing the
ABI would be disruptive; preparatory error-path wiring before a companion change
adds the production trigger. The goal is reviewable, mergeable diffs, not
comprehensive rewrites.

---

## How Real-World Conditions Trigger These Bugs

### Finding 1: git-hook-return-discard (refs.c:2736)

The `committed`-phase hook return value is discarded. This bug fires whenever a
`reference-transaction` hook fails *after* the ref is already written.

**Trigger conditions in production:**
- CI integration tracker unreachable (network partition, timeout) when the hook
  tries to notify it after a push lands
- Webhook endpoint times out or returns a server error
- Permission or rate-limit failure on a downstream side effect
- Bug in a custom hook script deployed to the server

**User-visible symptom:** `git push` exits 0. The branch is updated. The side
effect (PR tracking, audit log, security alert, CI trigger) is silently dropped.
No error. No log entry. No retry.

The `preparing` and `prepared` phases are correctly checked — a hook failure there
aborts the push before the ref is written. The asymmetry creates a false sense that
the hook contract is fully enforced: pre-write failures are loud, post-write failures
are silent.

For deployments where the `committed`-phase hook enforces security-relevant side
effects (access audit, SIEM notification, sync to a secondary auth store), a
transient failure during a push silently drops the security record with no indication
that it happened.

---

### Finding 2: git-merge-ort rename-pipeline-discard (merge-ort.c:detect_and_process_renames)

The rename detection pipeline has no `-1` error return path. The four unchecked
calls in `detect_and_process_renames` cannot distinguish "detection ran successfully"
from "detection ran but encountered an internal error and left the pairs array empty."

**This bug has no wild reproducer today** — `diffcore_rename_extended` does not
return errors, so there is currently no observable production condition that triggers
the silent-failure path on stock unmodified git. The finding is structural: any
future change that introduces a failable code path inside rename detection would
silently produce wrong merged trees.

**Why this matters in production environments:**

Distributed merge orchestrators and CI/CD merge queue systems run git as a backend
across multiple execution contexts. The test phase (Phase A) and the commit phase
(Phase B) may run in different environments: different VMs, different memory states,
different cache temperatures, different levels of concurrent load. If rename detection
encounters a partial failure in Phase B (object-fetch timeout under load, memory
pressure during pack negotiation, VM rotation mid-execution) but not in Phase A,
the tree committed in Phase B silently diverges from the tree CI tested in Phase A.

The user-visible symptom is "the merged tree does not match what CI approved" —
a class of incident sometimes called "merge queue tree corruption." The `ort` merge
strategy's silent-success semantics make this extremely difficult to detect without
an independent tree comparison step after every merge.

**Defensive-coding stance:** better to fail loud (exit 2, rollback) than to commit
a wrong tree silently. The patch adds the error paths and the patch cleanroom shows
they activate correctly under simulated failure. When `diffcore_rename_extended`
eventually gains error signaling (e.g., for partial-clone lazy-fetch support), the
propagation path will already exist.

---

## Repository Layout

```
findings/
  git-hook-return-discard/          Bug cleanroom: refs.c committed-phase return discarded
    Dockerfile                      docker build + run to reproduce
    README.md                       Structural description + analysis
    SOURCES.md                      Source citations (file, line, function)
    REPRODUCER.md                   Standalone shell reproducer + impact analysis
    PATCH.diff                      Proposed patch (illustrative diff)
    STATUS.md                       Submission status + next steps
    DETECTOR_OUTPUT.json            Raw detector output (FlowAsymmetry + ErrorPropagation)
    references/
      git-source-snippet.c          Relevant source excerpt
      cross-lens-profile.json       Vocab + CFG lens fingerprint

  git-hook-return-discard-patch/    Patch cleanroom: verifies the warning() fix
    Dockerfile                      docker build + run (builds git from source, ~15s)
    README.md
    STATUS.md

  git-merge-ort-rename-pipeline-discard/   Bug cleanroom: merge-ort pipeline structural gap
    Dockerfile                      (no wild reproducer — documentation-only)
    README.md
    SOURCES.md
    STATUS.md
    DETECTOR_OUTPUT.json
    references/
      git-source-snippet.c

  git-merge-ort-rename-pipeline-discard-patch/  Patch cleanroom: verifies error propagation
    Dockerfile                      docker build + run (builds git from source, ~15s)
    README.md
    STATUS.md

run_all.sh                          Runs all cleanrooms end-to-end
MANIFEST.md                         One-line index of all findings
```

---

## How to Verify

**Run everything:**
```sh
./run_all.sh
```

**Per-finding (bug cleanroom):**
```sh
cd findings/git-hook-return-discard
docker build -t git-hook-return-discard . && docker run --rm git-hook-return-discard
# Expected: CONTRADICTION: git push exited 0 and ref was written, but hook failed
```

**Per-finding (patch cleanroom):**
```sh
cd findings/git-hook-return-discard-patch
docker build -t git-hook-return-discard-patch . && docker run --rm git-hook-return-discard-patch
# Expected: PASS (PATCHED): git push exited 0 and emitted warning about hook failure

cd findings/git-merge-ort-rename-pipeline-discard-patch
docker build -t git-merge-ort-patch . && docker run --rm git-merge-ort-patch
# Expected: PASS (PATCHED): rename detection failure propagates as merge abort
```

Build time: ~2s for Alpine stock-git images, ~15s for from-source builds.

---

## Ongoing Work

These findings were produced by [alembic](https://github.com/rhCat/hyperHarness),
a static analysis tool that applies the three-lens methodology above to C, Rust,
and other language corpora. The underlying detectors (`FlowAsymmetry`,
`ErrorPropagation`, unified-vocab gate extraction via libclang) are what surfaced
both findings here.

Current work includes extending the empirical lens with a CVE pattern catalog
(mapping historical CVE classes to detector signatures), and cross-language
vocabulary normalization so the same detector logic applies across C, Rust, and JVM
codebases without reimplementation.

Additional findings from the git corpus and other open-source projects are under
investigation and will be added to this repository as cleanrooms are completed.

---

## Contributing

Additional findings, corrections to analysis, and patch improvements are welcome.
Please open an issue or PR. Findings should follow the same two-cleanroom structure
(bug + patch, never bundled) and include a Dockerfile that anyone can run independently.

---

## License

MIT — see [LICENSE](LICENSE).
