# AGENTS

## Role

This repository is the canonical WCP Archive host for Ae.solator releases.

## 2026-03-21 Push Priority

- During the active 2026-03-21 sync window, another agent may already be
  working in this repo. Fetch first and inspect today's remote heads before
  starting a new local batch.
- Today's first priority is publishing the source-first omega handoff batch if
  it is still only local, not opening a new unrelated build/debug pass.
- The required companion push for this repo includes:
  - `AGENTS.md`
  - `scripts/resume_freewine_local_build.sh`
  - any same-batch workspace migration / live-log docs and scripts that are
    already coherent and ready for publication
- This repo must stay aligned with the paired `freewine11` source-of-truth
  push. Do not publish a handoff story here that points to an older runtime
  source state.
- Do not push junk:
  - `__pycache__`
  - `.rej`
  - `.orig`
  - device-local temp outputs or logs
- See `docs/TODAY_PUSH_SYNC_ROADMAP.md` before pushing.

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
  - invalidate broken zero-size PE artifacts in `build-wine` before resume
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
- Expect the source-side omega report to classify zero-size PE artifacts in
  `build-wine` as part of the closure state, so a `not a COFF object` class is
  visible before the next resume loop trips over one file.
- Expect the source-side omega report to classify the generated
  `build-wine/libs/winecrt0/Makefile` root arm64 helper targets as part of the
  live build surface; do not assume everything important lives only under
  `aarch64-windows` / `arm64ec-windows` / `i386-windows`.
- A `not a COFF object` stop from `winebuild` / `lld-link` must be treated as
  a broken-artifact batch across `build-wine`, not as a one-object incident.
  Resume tooling should invalidate all affected PE archdirs before the next
  `make`.
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
- When the full source-side omega pass is CPU-bound, expect the canonical
  parser to run in fork-based multi-process mode with a preloaded read-only
  text surface; do not treat the old serial loop as the intended baseline.
- During a live whole-frontier omega run, expect summary-only checkpoint
  reports until the final render; do not wait for per-module markdown detail
  before taking the parser result back into the mirror.
- Prefer the omega JSON sidecar from `freewine11/.freewine11/` as the machine
  handoff for downstream batch tooling; markdown is the human report, JSON is
  the batch contract.
- Expect that JSON sidecar to contain the exhaustive per-module symbol
  inventory, not only counts:
  `module_files`, `entry_files`, `preproc_defs`, `raw_call_unique`,
  `candidate_calls`, `local_defs`, `self_exports`, `imported_exports`, and the
  full provider map.
- Expect that JSON sidecar to contain the exhaustive per-module build-object
  census too: generated module `Makefile` targets, artifacts grouped by
  archdir/root/unix, source-stem candidates, object stems, and uncovered
  build-object stems from the active `build-wine` tree.
- When runtime work is in parser-uplift/migration mode, keep the local mirror
  in parser-first mode until the whole-frontier source/build/object census is
  closed across `dlls`, `libs`, `include`, `loader`, `server`, `programs`, and
  `tools`; do not bounce between shallow rebuilds and partial parser changes.
- Treat local donor trees plus primary upstream/public sources as part of the
  source-side omega contract before mirroring broad parser heuristics back into
  `wine-src`.
- Generated parser stems are part of the contract: `.idl` -> `_c/_s/_p/dlldata`,
  `.y` -> `.tab`, `.l` -> `.yy`. Do not resume build while source-side omega
  still reports those as uncovered build-object stems.
- Treat shim DSL placeholder names such as `name` / `target` as parser noise,
  not as real duplicate-provider evidence to mirror into `wine-src`.
- When the source-side omega parser reports imported-and-locally-owned symbols
  or known-class hits that survive only through local/export collisions, mirror
  that as owner-drift cleanup work, not as another unresolved include-fill.
- When `freewine11` removes a shared `.inc` -> foreign `.c` dependency or
  splits a driver/runtime carrier into a new shared `.inc`, do not resume the
  local mirror build until
  `freewine11/.freewine11/sweep_arm64_compile_surface.py` reports
  `status: CLEAN` on the current `build-wine/compile_commands.json`.
- When the source-side stop is a recursive provider overlap between a family
  include and a central shim include, do not mirror until the source tree has
  been cleaned by `freewine11/.freewine11/apply_arm64_overlap_guard_batch.py`
  and `freewine11/.freewine11/scan_arm64_shim_overlaps.py` is `CLEAN`.
- When the source-side stop is `.spec` forwarder drift, do not mirror until
  `freewine11/.freewine11/scan_arm64_forwarded_owner_collisions.py` is
  `CLEAN` after source-side cleanup with
  `freewine11/.freewine11/apply_arm64_forwarded_owner_cleanup.py`.
- When source-side omega reports `import_contract_parapet: DIRTY`, do not
  mirror or resume the local tree until the source tree has been cleaned with
  `freewine11/.freewine11/apply_arm64_import_contract_parapet_batch.py` and a
  fresh omega rerun confirms the class is gone.
- Treat `file(1)`-only PE-integrity hits as suspect. Wait for source-side
  LLVM-based build-integrity confirmation before invalidating large `build-wine`
  archdirs.
- Treat split-line generated defs and macro-bodied defs as a parser-owned
  source-truth class. Do not mirror or resume `build-wine` while omega still
  thinks names like `yydestruct`, `mpg123_info2`, `mpg123_getformat2`, or the
  `bad_*` readers family are unresolved imports; that class must be fixed in
  the source-side local-def extractor first.
- Treat local callable identifiers from parameters, function-pointer locals,
  and simple local declarations as parser noise, not import gaps. If omega
  reports names like `copy`, `compare`, or `decode`, fix the source-side
  candidate-call filtering before resuming the same build tree.
- When the source-side stop is a `winecrt0` private-register class, do not
  mirror until the shared source carrier has been fixed in
  `arm64_register_import_shims.inc` and, when active in the family graph,
  `arm64_register_import_shims_noheap.inc`; do not mirror a leaf-only
  `EnumResourceNamesW` / `FindResourceW` / `LoadResource` / `SizeofResource`
  patch.
- If a fresh local mirror rotation happens before the next clean build, do not
  assume the old linker tail still describes the live source problem; recheck
  the class on the refreshed `wine-src` first.
- If the fresh `build-wine` has not generated a new `compile_commands.json`
  yet, whole-frontier omega closure should temporarily use the previous stable
  `build-wine.prev.../compile_commands.json` while reading the current
  source-of-truth and refreshed mirror files.
- Whole-frontier omega closure must preserve active `__WINE_ARM64_*` guard
  macros across sibling shim includes in the same translation unit; otherwise
  guarded include layers will look like duplicate providers when they are not.
- Whole-frontier omega closure must also honor late `#undef __WINE_ARM64_*`
  transitions in wrapper include chains; parent-family owner macros that are
  explicitly unmasked in the child translation unit must not survive into
  omega as false missing providers.
- Whole-frontier omega closure must not let partial `compile_commands`
  coverage replace the module's real source/build-generated surface; treat
  `compile_commands` as a supplement and still merge repo sources,
  `PARENTSRC`, and generated `build-wine` sources into the module surface.
- Whole-frontier omega closure must treat top-level function declarations in
  preprocessed text as declarations, not as call-sites; prototype pollution
  from headers / `extern` blocks must be filtered before unresolved-symbol
  derivation.
- Whole-frontier omega closure must not mirror raw local-def hits that come
  from multiline conditionals. Comparison/boolean tails (`==`, `!=`, `&&`,
  `||`) and lone callee heads without a return-type token are parser noise,
  not owner definitions to sync into `wine-src`.
- Source-side symbol scanners that accept regex unions must record the full
  matched symbol name, not capture-group tuples; grouped alternations in
  queries such as `Dde(...)` / `SHReg(...)` are scanner input syntax, not the
  source-of-truth symbol identity.
- If a source module `Makefile.in` declares `PROXY_DELEGATION` or
  `dlldata_EXTRADEFS`, treat generated RPC proxy glue as part of the module
  surface even when the repo tree only contains `.idl`; source-side
  module-owner scans should augment candidates with the shared
  `arm64_rpc_proxy_import_shims.inc` surface plus `DisableThreadLibraryCalls`
  before the next mirror/resume decision.
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
    `__WINE_ARM64_OWNS_*` guards in leaf shim files via
    `freewine11/.freewine11/scan_arm64_forwarded_owner_collisions.py` and
    `freewine11/.freewine11/apply_arm64_forwarded_owner_cleanup.py`
    but with a hard preserve rule for symbols that also have a real
    module-local definition, so the cleanup does not strip legitimate owners
    such as `user32.DefWindowProcA/W`
    and the same owner-sweep rule for `.spec` `-import` export surfaces
    and synthetic inactive arch macros in parser defs treated as effectively
    undefined for `defined(...)` / `#ifdef` so foreign `i386` / `x86_64`
    sources do not leak false ARM64 local defs
    and source-level `__ASM_GLOBAL_FUNC(...)` / `__ASM_STDCALL_FUNC(...)`
    branch targets promoted into omega candidate-calls, because hidden jumps
    such as `_setjmp -> _setjmpex` are real closure edges
    and arch-aware, contract-aware `.spec` parsing that ignores foreign
    `-arch=` exports and surfaces missing local export targets as
    export-contract gaps instead of hiding the class behind imported exports
    and call-shaped header-wrapper extraction so inline/header bodies do not
    leak local identifiers such as `table` into omega unresolveds
    and an exact symbol-specific raw source-def probe before declaring a late
    `export_contract` target missing
    and `llvm-nm` confirmation of generated/exported build surface when
    source/provider/import checks still leave an export-contract tail on a
    built module such as `ntdll`
    and a shared-surface move into `include/wine/` when `omega` leaves only
    module-local family/proxy `imported-and-locally-owned` drift, with
    `winecrt0` private owner objects as the only normal allowlisted exception
    and a shared-carrier fix when `winecrt0` private register imports require
    `arm64_resource_loader_import_shims.inc` transitively through
    `arm64_register_import_shims.inc`
    while suppressing only `__wine_register_resources` and
    `__wine_unregister_resources` at that carrier boundary because the real
    owner is `libwinecrt0 register.o`
    and a shared-carrier fix when `arm64_interlocked_import_shims.inc` ignores
    owner guards for part of the `Interlocked*` family
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
  - warning-derived owner-guard batching for same-module `LNK4217` records
    emitted by `arm64_import_shims.o`, with stale-log demotion once the
    current source tree already carries the matching `__WINE_ARM64_OWNS_*`
    guard
  - linked-static-owner collision detection in omega so leaf shim providers
    that duplicate `libwinecrt0` or other `libs/*` owners are surfaced before
    the live linker stop
  - loader-carrier cleanup when `arm64_loader_import_shims.inc` leaks
    `__wine_unix_call_dispatcher` / `__wine_init_unix_call` /
    `__wine_load_unix_lib` / `__wine_unload_unix_lib` over the real owner in
    `libwinecrt0(unix_lib.o)`
  - imported-export parapet cleanup with
    `freewine11/.freewine11/apply_arm64_import_contract_parapet_batch.py`
    anchored to the last `RESUME` slice with root-cause classification and
    undefined-symbol context, not flat totals
  - provider-required imported-only RPC client-stub symbols such as
    `NdrClientCall2`, which must be audited across the whole frontier with
    `--import-contract-parapet all` instead of being hidden behind
    `prefer-native` filtering
  - duplicate-provider cleanup after core omega closure, where specialized
    family carriers must be trimmed back to their unique helpers if they leak
    generic central-owner symbols into runtime lanes
  - omega closure classification from
    `freewine11/.freewine11/omega_arm64_closure_parser.py`
    including live-stop duplicate symbols, shim-vs-local owner collisions, and
    shim-vs-self-export collisions
    plus `--import-contract-parapet prefer-native|all` when imported exports
    must be distinguished from real ARM64 carrier coverage across the whole
    remaining frontier
  - owner-local collision cleanup on the true owner DLL by preserving the
    shared carrier and restoring `__WINE_ARM64_OWNS_*` guards in the owner
    module instead of globally suppressing the family symbols in `wine-src`
  - native-driver import-coverage classification that allowlists helper/debug
    imports such as `IsBadStringPtrA/W`, `__wine_dbg_strdup`, and
    `__wine_dbg_get_channel_flags` until the live build proves they are a real
    unresolved or duplicate-owner class
  - provider-surface measurement that counts extra module-local ARM64 shim
    source objects, not only `arm64_import_shims.c`, before deciding a late
    `winecrt0` or split-owner class is still unresolved
- Canonical local log window launcher:
  - `scripts/open_freewine_live_log.sh`
  Use it instead of ad-hoc `gnome-terminal` invocations so the live log opens
  with the correct default log path and session environment. On Wayland, it
  should prefer the GUI tail fallback instead of forcing an X11-only terminal
  path.
- When a module has `UNIXLIB` plus `arm64_loader_import_shims.inc`, or uses
  `arm64_register_import_shims.inc` / `arm64_register_import_shims_noheap.inc`,
  treat the matching `libwinecrt0.a` unix/register helpers as an implicit
  linked static provider layer in omega before classifying
  `__wine_init_unix_call`, `__wine_load_unix_lib`,
  `__wine_unload_unix_lib`, `__wine_register_resources`, or
  `__wine_unregister_resources` as real residuals.
- When a runtime family depends on `UNIX_LIBS` instead of PE imports, source
  omega must carry those measured external provider hints into the linked
  provider layer before declaring residuals; do not mirror/resume a build on
  top of a stale `winegstreamer`-style false gap.
- When module source directly references internal `libwinecrt0` helpers with
  `__wine_*` names, count those symbols as linked static providers from
  `libs/winecrt0` even if the module has no `UNIXLIB` marker or family
  carrier include; do not keep `mmdevapi` / `mp3dmod` style direct helper
  calls in the residual bucket.
- For `libs/*` provider surfaces, prefer the built
  `build-wine/libs/*/*-windows/lib*.a` archives via `llvm-nm` before
  source-level donor scans; keep source scans as fallback only when the
  archive is missing.
- When source omega normalizes `llvm-nm` symbols from built ARM64 archives,
  objects, or PE artifacts, preserve semantic leading `_`, strip leading `#`,
  and strip `$...` thunk suffixes before comparing provider/export surfaces.
- `import_contract_parapet` is not clean until it also subtracts
  `linked_provider_symbols`, `built_artifact_exports`, and
  `built_arm64_owner_symbols`; do not resume `build-wine` on imported-only
  drift that is already covered by static or built owners.
- For wrapper modules that include another DLL family's `arm64_import_shims.c`,
  trust source omega over stale build warnings: inherited owner macros can
  suppress generic carriers in the wrapper, so fix that class in the shared
  unmask layer before the next dense build.
- Same-module `LNK4217` from `arm64_import_shims.o` should be treated as stale
  at the build-orchestrator layer once source omega proves the symbol is still
  present in the live provider set or built ARM64 owner surface.
- If a shared shim overlap fix depends on include order, keep it in
  parser-visible `#ifdef` / `#ifndef` form so the canonical omega rerun and
  the live compiler see the same carrier surface.
- If source omega proves the machine can sustain a wider worker budget than
  autosize actually selected, use an explicit `--jobs` override on the
  canonical rerun before the next dense build handoff.

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

## 2026-03-21 Runtime Addendum

- Treat leaf `__WINE_ARM64_OWNS_*` walls over generic `Heap*`, `Global*`,
  `CreateFileW`, `ReadFile`, `CloseHandle`, and `lstrcmpiW` as a distinct
  runtime class when the same translation unit already includes the central
  generic carriers for those symbols.
- Solve that class by reopening the shared carrier layer before the include
  graph and validating the built `arm64_import_shims.o` export surface with
  `llvm-nm`, not by adding one-symbol leaf shims.
- Seed the omega preprocessor model with the real active clang/gcc builtin
  macros; compiler-gated `__GNUC__` / `__clang__` branches in runtime source
  are part of the ARM64 closure map, not dead code.
- If a module header closure reaches `include/wine/exception.h`, treat the
  `libwinecrt0` exception helper family as an implicit linked static provider
  layer before classifying `__wine_setjmpex` as unresolved.
