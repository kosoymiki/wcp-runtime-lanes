# AGENTS

## Role

This repository is the canonical WCP Archive host for Ae.solator releases.

## Rules

- Treat this repo as the archive/release orchestrator, not the primary source
  of app or runtime code.
- Runtime source-of-truth lives in `freewine11`.
- App source-of-truth lives in `aeolator`.
- Local mirrors such as `wine-src` are scratch build inputs, not documentation
  or source-of-truth.
- This repo is the canonical CI/release host for heavy shared toolchain lanes
  such as the Android/Termux host `LLVM 22.1.1` compiler build. If that
  compiler is built in GitHub Actions and published as a release asset, it
  belongs here rather than in `aeolator`.
- Default git posture here is `main`-first. Do not spin normal work into side
  branches or staged merge branches unless the user explicitly asks for that.
- For local FreeWine loops, mirror proven runtime fixes from `freewine11` and
  keep using the same `build-wine` tree whenever structurally possible.
- Do not let `wine-src` become the only place where a learned runtime fix or
  failure-class understanding exists.
- When a broad parent-layer fix reopens a large dependency family, treat that
  as valid build-graph work, not as a false regression.
- When resuming a repeated ARM64 shim class, mirror the whole validated family
  batch from `freewine11` into `wine-src`, not only the single DLL that
  appeared in the most recent linker tail.
- Mirror graph-wide closure batches from `freewine11` into `wine-src` when the
  remaining build still carries the same class across siblings, wrappers,
  native drivers, or `UNIXLIB` branches.
- The default local-runtime assumption is broad closure, not one-module repair:
  if a class remains plausible elsewhere in the remaining graph, the mirror
  should be widened before the next sibling stops the build.
- The active remaining `make` graph is the mirror boundary:
  - sync every validated family member still present in the remaining frontier
  - do not mirror only the DLL named in the latest linker tail if the same
    class still exists across the rest of the graph
  - resume scripts and stale-output invalidation must preserve graph-wide
    closure logic instead of reintroducing one-by-one repair
- Resume logic must preserve the distinction between:
  - current log progress
  - actual build-tree maturity
  - remaining fundamental graph after broad family invalidation
- Runtime-side working memory is owned by:
  - `/home/mikhail/wcp-sources/freewine11/.freewine11/BUILD_FAILURE_CLASS_MEMORY.md`

## Main Docs

- `README.md`
- `docs/MAINLINE_PROJECT_STATE.md`
- `docs/UNIFIED_RUNTIME_CONTRACT.md`
- `docs/LOCAL_SOURCE_LAYOUT.md`
