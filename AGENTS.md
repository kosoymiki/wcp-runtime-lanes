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
- Default local-runtime loop is execution-first and final-result oriented:
  - consume parser-backed batches from `freewine11`
  - sync the owning source changes into `wine-src`
  - resume the same `build-wine` tree
  - keep advancing to the next real frontier instead of stopping for staged
    consultative checkpoints
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
- When `freewine11` splits `winecrt0` public hook ownership from generic shim
  owners, mirror that object-layout change into `wine-src` before the next
  resume or late DLL links can keep pulling stale central owners.
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
- When a repeated ARM64 class is under active closure, prefer parser-backed
  owner-gap analysis from `freewine11/.freewine11/` before mirroring the next
  batch into `wine-src`.
- For CRT/runtime-text classes, mirror only after the source-side parser has
  measured the class from real entry files plus the transitive repo include
  graph; do not widen `wine-src` from flat header grep.
- When the live stop is a duplicate-symbol or self-owner class, prefer the
  omega parser from `freewine11/.freewine11/` before the next mirror/resume so
  `wine-src` does not reimport the same owner collision.
- When the source-side stop is a recursive provider overlap between a family
  include and a central shim include, do not mirror until the source tree has
  been cleaned by `freewine11/.freewine11/apply_arm64_overlap_guard_batch.py`
  and `freewine11/.freewine11/scan_arm64_shim_overlaps.py` is `CLEAN`.
- If a fresh local mirror rotation happens before the next clean build, do not
  assume the old linker tail still describes the live source problem; recheck
  the class on the refreshed `wine-src` first.
- If the fresh `build-wine` has not generated a new `compile_commands.json`
  yet, whole-frontier omega closure should temporarily use the previous stable
  `build-wine.prev.../compile_commands.json` while reading the current
  source-of-truth and refreshed mirror files.
- Mirror parser-derived family batches, not speculative one-symbol fixes.
- If parser or warning analysis identifies stale core runtime/server structure
  initializers, mirror the source-side family contract fix on the next resume;
  do not hide it behind extra warning suppression in the build mirror.
- For the late frontier, also mirror parser-backed pre-link prediction:
  - source owner-gap scans
  - remaining-graph scans
  - known owner-class scans across the full still-remaining graph
  - unresolved-symbol prediction for the still-remaining `winegcc` links
  - whole-tree shim analysis for broad owner-layer closure
  - the make-driven closure map from `freewine11/.freewine11/ARM64_MAKE_FRONTIER_CLOSURE_MAP.md`
    including `PARENTSRC`, `UNIXLIB`, and external library linkage
  - the layer-logic map from `freewine11/.freewine11/ARM64_LAYER_LOGIC_MAP.md`
    including layer classification, compile-unit coverage, live frontier, and
    downstream blast radius
  - the all-layer dashboard from `freewine11/.freewine11/ARM64_CLOSURE_DASHBOARD.md`
  - real build-tree remaining-link analysis from `build-wine`
  - parser-driven owner-batch application from saved scan outputs
  - parser-driven owner-guard synthesis from
    `freewine11/.freewine11/apply_arm64_owner_guard_batch.py`
  - parser-driven safe include-fill from
    `freewine11/.freewine11/apply_arm64_safe_include_gap_batch.py`
    with a post-batch grep for `.inc"#include` before resuming `build-wine`
    and a full-tree top-block normalization via
    `freewine11/.freewine11/normalize_arm64_import_shims_layout.py` when the
    first include block was left adjacent to the define/owner block
    and a whole-tree process-heap provider sweep via
    `freewine11/.freewine11/apply_arm64_process_heap_provider_batch.py`
    when heap/loader consumers lack a transitive process-heap shim carrier
    and a forwarded-export owner sweep so `.spec` forwards do not keep stale
    `__WINE_ARM64_OWNS_*` guards in leaf shim files
    followed by another owner-guard sweep when an owner module gained a new
    broad shared include
  - CRT header-surface measurement from
    `freewine11/.freewine11/scan_arm64_crt_header_surface.py`
    and
  - macro-aware recursive overlap cleanup from
    `freewine11/.freewine11/apply_arm64_overlap_guard_batch.py`
    followed by `freewine11/.freewine11/scan_arm64_shim_overlaps.py`
    returning `CLEAN`
    `freewine11/.freewine11/ARM64_CRT_HEADER_SURFACE.md`
    so runtime-text mirroring respects carrier headers and wrapper activation
  - warning-log aggregation for `LNK4217`, `pragma-pack`, and related live
    warning classes
  - omega closure classification from
    `freewine11/.freewine11/omega_arm64_closure_parser.py`
    including live-stop duplicate symbols, shim-vs-local owner collisions, and
    shim-vs-self-export collisions
  - provider-surface measurement that counts extra module-local ARM64 shim
    source objects, not only `arm64_import_shims.c`, before deciding a late
    `winecrt0` or split-owner class is still unresolved
- Canonical local log window launcher:
  - `scripts/open_freewine_live_log.sh`
  Use it instead of ad-hoc `gnome-terminal` invocations so the live log opens
  with the correct default log path and session environment. On Wayland, it
  should prefer the GUI tail fallback instead of forcing an X11-only terminal
  path.

## Device Migration And Handoff

- Runtime-lanes owns the canonical workspace handoff tooling for device moves.
- Preserve for immediate Codex resume:
  - `/home/mikhail/AGENTS.md`
  - `/home/mikhail/.codex`
  - `/home/mikhail/wcp-sources`
- Generate fresh handoff artifacts before the move:
  - `/home/mikhail/WORKSPACE_HANDOFF.md`
  - `/home/mikhail/WORKSPACE_HANDOFF.json`
- Canonical tools:
  - `scripts/generate_workspace_handoff.py`
  - `scripts/stage_workspace_migration.sh`
- Canonical procedure doc:
  - `docs/WORKSPACE_MIGRATION_AND_HANDOFF.md`
- Preserve `build-wine`, `wine-src`, `.cache`, `.localdeps`, and log history
  when the goal is immediate build-loop continuity.
- If the copied `build-wine` tree is not valid on the destination host,
  rebuild it from `scripts/rebuild_freewine_local_build.sh` instead of
  assuming the copied outputs remain usable.

## Main Docs

- `README.md`
- `docs/MAINLINE_PROJECT_STATE.md`
- `docs/UNIFIED_RUNTIME_CONTRACT.md`
- `docs/LOCAL_SOURCE_LAYOUT.md`
