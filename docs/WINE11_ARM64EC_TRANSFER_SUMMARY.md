# Wine11 ARM64EC Transfer Summary

This document is the current top-level map of active Wine11 transfer lanes.

The strict next-wave execution queue is tracked separately in
`docs/WINE11_ARM64EC_25_STEP_ROADMAP.md`.
The blocker-driven exit from repeated proof-only waves is tracked in
`docs/WINE11_ARM64EC_COMPLETION_PROGRAM.md`.
The current frozen-core blocker map is tracked in
`docs/WINE11_ARM64EC_FROZEN_CORE_EXIT_ANALYSIS.md`.
The loader-specific owned plan remains tracked in
`docs/WINE11_ARM64EC_LOADER_FULL_SPECTRUM_PLAN.md`.
The current wow64-first bridge plan remains tracked in
`docs/WINE11_ARM64EC_WOW64_FULL_SPECTRUM_PLAN.md`.
The opened `kernelbase`, `win32u`, `kernel32`, and `dlls-wave1` release-library lanes are tracked in
`docs/WINE11_ARM64EC_KERNELBASE_FULL_SPECTRUM_PLAN.md` and
`docs/WINE11_ARM64EC_WIN32U_FULL_SPECTRUM_PLAN.md` and
`docs/WINE11_ARM64EC_KERNEL32_FULL_SPECTRUM_PLAN.md` and
`docs/WINE11_ARM64EC_DLLS_WAVE1_FULL_SPECTRUM_PLAN.md`.
Current lane-queue status is tracked in
`docs/WINE11_ARM64EC_LANE_VALIDATION_QUEUE.md`.

## Active Runtime Lanes

- `core-runtime`: baseline narrow runtime transfer lane on top of the in-repo GameNative wine patch base (`15` runtime slices, intentionally frozen).
- `loader-runtime`: dedicated `dlls/ntdll/unix/loader.c` runtime lane on top of `core-runtime` (`9` file-local slices, intentionally frozen).
- `signal-runtime`: dedicated `ntdll` signal lane on top of `loader-runtime` (`13` runtime slices, intentionally frozen).
- `server-runtime`: dedicated server-side runtime lane on top of `signal-runtime` (`5` runtime slices, with protocol shape still isolated into support and intentionally frozen).

## Active Support Lanes

- `loader-support`: validated-empty `ntdll.spec` / `ntdll_misc.h` lane for loader-adjacent runtime slices.
- `signal-support`: validated-empty `ntdll.spec` / `ntdll_misc.h` lane for signal-adjacent runtime slices.
- `server-support`: active `server/protocol.def` lane with `1` minimal protocol unblocker for `read_process_memory`.
- `wow64-support`: active `include/winternl.h` / `dlls/wow64/wow64.spec` lane with `2` declaration-side unblockers for ongoing wow64 bridge growth.
- `wow64-struct-support`: active `dlls/wow64/struct32.h` lane with `1` 32-bit structure-side unblocker for bridge growth that could not stay file-local inside `core-runtime`.
- `libs-wine-support`: validated-empty `libs/wine/` lane for helper-library-side dependencies.
- `winebuild-support`: validated-empty `tools/winebuild/` lane for future build-side thunk/export generation dependencies.

## Opened Deferred Release Lanes

- `kernelbase-runtime`: first deferred non-core release-library lane, now gate-proven on top of the full frozen core stack with `6` landed file-local runtime slices.
- `kernelbase-support`: deferred `dlls/kernelbase/kernelbase.spec` lane, now gate-proven on top of `kernelbase-runtime` and currently empty.
- `win32u-runtime`: second deferred non-core release-library lane, now gate-proven on top of `kernelbase-support` with `7` landed file-local runtime slices.
- `win32u-support`: still deferred; it is not opened yet.
- `kernel32-runtime`: third deferred non-core release-library lane, now gate-proven on top of `win32u-runtime` with `1` landed file-local runtime slice.
- `kernel32-support`: still deferred; it is not opened yet.
- `dlls-wave1-runtime`: fourth deferred non-core runtime lane on top of `kernel32-runtime`; after the initial (`acledit .. bcrypt`) bundle it is widened in transfer-first mode with `dlls/` umbrella scope and `2447` landed slices, now gate-proven end-to-end in the current queue checkpoint.
- `include-libs-wave1-runtime`: fifth deferred non-core runtime lane on top of `dlls-wave1-runtime`; opened for `include/` + `libs/` transfer-first ownership with `564` landed slices, now gate-proven end-to-end in the current queue checkpoint.
- `nls-po-programs-server-tools-wave1-runtime`: sixth deferred non-core runtime lane on top of `include-libs-wave1-runtime`; opened for `nls/` + `po/` + `programs/` + `server/` + `tools/` transfer-first ownership with `313` landed slices, now gate-proven end-to-end in the current queue checkpoint.
- `documentation-fonts-root-wave1-runtime`: seventh deferred non-core runtime lane on top of `nls-po-programs-server-tools-wave1-runtime`; opened for `documentation/` + `fonts/` + selected repo-root contract files with `28` landed slices, now gate-proven end-to-end in the current queue checkpoint.
- `tkg-ge-wave6-runtime`: selective Wave6 donor lane opened on top of `documentation-fonts-root-wave1-runtime`; promoted as `30` proven patches and now closed through deferred recovery to `19` landed lane patches + `11` absorbed/superseded (full `24/24` deferred queue closure, `0` open).

## Completion Estimate

- closed strict wave: `25 / 25` steps complete (`100%`), `0 / 25` steps remaining (`0%`)
- closed follow-up wave: `25 / 25` steps complete (`100%`), `0 / 25` steps remaining (`0%`)
- closed freeze-recheck wave: `25 / 25` steps complete (`100%`), `0 / 25` steps remaining (`0%`)
- active next wave: `0 / 25` steps complete (`0%`), `25 / 25` steps remaining (`100%`)
- four-wave aggregate: `75 / 100` steps complete (`75%`), `25 / 100` steps remaining (`25%`)
- latest stability checkpoint (`2026-03-03`): `70 / 70` `run-kernel32-runtime-gates.sh` cycles pass (`100%`)
  - see `docs/WINE11_ARM64EC_10x25_BATCH_REPORT.md`
- latest lane-queue checkpoint (`2026-03-04`): `18 / 18` lane checks pass (`100%`), queue remaining `0`
  - see `docs/WINE11_ARM64EC_LANE_VALIDATION_QUEUE.md`
- reflective whole-program estimate for the current owned `Wine11 ARM64EC` transfer block
  (`core + loader + signal + server + wow64 + support lanes`, plus opened `kernelbase`, `win32u-runtime`, `kernel32-runtime`, `dlls-wave1-runtime`, `include-libs-wave1-runtime`, `nls-po-programs-server-tools-wave1-runtime`, `documentation-fonts-root-wave1-runtime`, and `tkg-ge-wave6-runtime`):
  about `82%` complete, about `18%` remaining

This `82 / 18` estimate is intentionally scoped to the current owned transfer program, not to a
literal full parity merge of every remaining file in `Valve experimental_10.0`.

## Completion Mode

Repeated proof-only `25-step` wave resets are no longer treated as transfer progress by
themselves. The real blocker-driven exit path is tracked in
`docs/WINE11_ARM64EC_COMPLETION_PROGRAM.md`.

From this point, real forward movement means one of:

- a new runtime patch lands in a frozen lane
- a new support patch lands because it unblocks a concrete runtime patch
- a new deferred library lane opens with its own full-spectrum ownership plan

## Ordering Contract

Every new lane must prove itself on top of all earlier lanes in the chain.

Current dependency order:

1. GameNative wine patch base
2. `core-runtime`
3. `loader-runtime`
4. `signal-runtime`
5. `signal-support`
6. `server-runtime`
7. `server-support`
8. `wow64-support`
9. `wow64-struct-support`
10. `libs-wine-support`
11. `winebuild-support`
12. `kernelbase-runtime`
13. `kernelbase-support`
14. `win32u-runtime`
15. `win32u-support` (deferred)
16. `kernel32-runtime`
17. `kernel32-support` (deferred)
18. `dlls-wave1-runtime`
19. `include-libs-wave1-runtime`
20. `nls-po-programs-server-tools-wave1-runtime`
21. `documentation-fonts-root-wave1-runtime`
22. `tkg-ge-wave6-runtime`

## Current Wave State

- repeated `support-first` / `server-first` proof-only waves are now treated as exhausted for
  growth in the frozen core block
- the frozen core blocker map is now explicit in
  `docs/WINE11_ARM64EC_FROZEN_CORE_EXIT_ANALYSIS.md`
- the first real completion-mode widening block has landed and grown:
  - `kernelbase-runtime` is opened and full-chain gate-proven
  - `kernelbase-support` is opened and full-chain gate-proven
  - six real `kernelbase-runtime` slices are now landed in:
    - `dlls/kernelbase/file.c`
    - `dlls/kernelbase/process.c`
    - `dlls/kernelbase/debug.c`
      - includes both the `InitializeProcessForWsWatch()` stub fix and the `start_debugger_atomic()` `ERR_ON(seh)` guard
      - includes the `FindFirstFile/FindNextFile` `FileBothDirectoryInformation` runtime behavior slice
      - includes `CREATE_NO_WINDOW` for debugger spawn in `start_debugger()`
  - `kernelbase-support` remains intentionally empty because no spec/export dependency was proven
- the second real completion-mode widening block is now opened and grown:
  - `win32u-runtime` is opened and full-chain gate-proven on top of `kernelbase-support`
  - initial runtime scope is bounded to:
    - `dlls/win32u/sysparams.c`
    - `dlls/win32u/window.c`
    - `dlls/win32u/input.c`
    - `dlls/win32u/message.c`
    - `dlls/win32u/defwnd.c`
    - `dlls/win32u/vulkan.c`
  - first seven `win32u-runtime` slices are now landed:
    - `win32u-runtime/0001-sysparams-cast-sessionid-and-debugstr-fields.patch`
      - touches `dlls/win32u/sysparams.c`
    - `win32u-runtime/0002-window-send-notify-message-in-flashwindowex.patch`
      - touches `dlls/win32u/window.c`
    - `win32u-runtime/0003-input-track-enable-mouse-in-pointer-state.patch`
      - touches `dlls/win32u/input.c`
    - `win32u-runtime/0004-defwnd-cast-trace-coordinates.patch`
      - touches `dlls/win32u/defwnd.c`
    - `win32u-runtime/0005-defwnd-use-long-for-window-style-locals.patch`
      - touches `dlls/win32u/defwnd.c`
    - `win32u-runtime/0006-message-cast-low-level-hook-trace-fields.patch`
      - touches `dlls/win32u/message.c`
    - `win32u-runtime/0007-window-cast-windowplacement-trace-fields.patch`
      - touches `dlls/win32u/window.c`
  - `dlls/win32u/vulkan.c` is explicitly frozen for this wave after re-check
  - `win32u-support` remains deferred and unopened until a concrete runtime slice proves a support dependency
- the third real completion-mode widening block is now opened and re-checked:
  - `kernel32-runtime` is opened and full-chain gate-proven on top of `win32u-runtime`
  - initial runtime scope is bounded to:
    - `dlls/kernel32/process.c`
    - `dlls/kernel32/file.c`
    - `dlls/kernel32/sync.c`
    - `dlls/kernel32/path.c`
    - `dlls/kernel32/thread.c`
    - `dlls/kernel32/console.c`
  - first `kernel32-runtime` slice is now landed:
    - `kernel32-runtime/0001-process-add-wait-input-idle-fallback-wrapper.patch`
      - touches `dlls/kernel32/process.c`
  - `kernel32-runtime/0002` re-check is explicitly frozen (no safe bounded non-`process.c` slice yet)
    - latest re-check on `dlls/kernel32/file.c`, `dlls/kernel32/thread.c`, and
      `dlls/kernel32/console.c` stayed `no-diff` against current Valve head on prepared ownership base
  - `kernel32-support` remains deferred and unopened until a concrete runtime slice proves a support dependency
- the fourth widening block is now opened as a bounded bundle lane:
  - `dlls-wave1-runtime` is opened and gate-chained after `kernel32-runtime`
  - started from requested donor prefixes `dlls/acledit` through `dlls/bcrypt`, then widened to `dlls/` for transfer-first mode
  - landed slices: `2447` (`0001..2447` currently pass lane checks in one chain)
  - reflective `dlls/` coverage check currently reports `0` remaining Andre-vs-Valve file diffs after `0001..2447`
  - per-patch mapping is exported as `docs/WINE11_ARM64EC_DLLS_WAVE1_PATCH_INDEX.tsv`
- the fifth widening block is now opened for cross-layer ownership after `dlls-wave1-runtime`:
  - `include-libs-wave1-runtime` is opened and gate-chained after `dlls-wave1-runtime`
  - scope is explicitly bounded to:
    - `include/`
    - `libs/`
  - landed slices: `564` (`0001..0564` currently pass lane checks in one chain)
  - overlap and hot-file reflection is tracked in `docs/WINE11_ARM64EC_INCLUDE_LIBS_WAVE1_RUNTIME_REPORT.md`
- the sixth widening block is now opened after `include-libs-wave1-runtime`:
  - `nls-po-programs-server-tools-wave1-runtime` is opened and gate-chained after `include-libs-wave1-runtime`
  - scope is explicitly bounded to:
    - `nls/`
    - `po/`
    - `programs/`
    - `server/`
    - `tools/`
  - landed slices: `313` (`0001..0313` currently pass lane checks in one chain)
  - overlap and hot-file reflection is tracked in `docs/WINE11_ARM64EC_NLS_PO_PROGRAMS_SERVER_TOOLS_WAVE1_RUNTIME_REPORT.md`
- the seventh widening block is now opened after `nls-po-programs-server-tools-wave1-runtime`:
  - `documentation-fonts-root-wave1-runtime` is opened and gate-chained after `nls-po-programs-server-tools-wave1-runtime`
  - scope is explicitly bounded to:
    - `documentation/`
    - `fonts/`
    - `aclocal.m4`, `ANNOUNCE.md`, `AUTHORS`, `autogen.sh`, `configure.ac`, `COPYING.LIB`,
      `LICENSE`, `LICENSE.OLD`, `MAINTAINERS`, `README.esync`, `README.md`, `VERSION`
  - landed slices: `28` (`0001..0028` currently pass lane checks in one chain)
  - overlap and hot-file reflection is tracked in `docs/WINE11_ARM64EC_DOCUMENTATION_FONTS_ROOT_WAVE1_RUNTIME_REPORT.md`
- the eighth widening block is now opened after `documentation-fonts-root-wave1-runtime`:
  - `tkg-ge-wave6-runtime` is opened and gate-chained after `documentation-fonts-root-wave1-runtime`
  - promotion stage imported `30` Wave6 proven donor patches into a dedicated lane
  - stack-rebase on current owned chain produced:
    - `1` landed patch (`0308` msxml3 writer destination handling)
    - `2` absorbed patches already present on current stack
    - `27` deferred conflict patches tracked in stack-rebase report
  - deferred 3-way rebase additionally produced:
    - `3` extra landed patches (`0052`, `0282`, `1487`)
    - deferred queue reduced from `27` to `24`
  - deferred closure passes then produced:
    - `11` additional landed patches via sequential chain and `4` via manual rebase
    - `9` absorbed/superseded patches in the deferred queue
    - deferred queue closure state: `24 / 24` closed, `0` open
  - final Wave6 runtime lane state:
    - active lane patches: `19`
    - absorbed/superseded from the promoted `30`: `11`
  - stack-rebase details are tracked in:
    - `docs/WINE11_ARM64EC_TKG_GE_WAVE6_RUNTIME_STACK_REBASE.md`
    - `docs/WINE11_ARM64EC_TKG_GE_WAVE6_DEFERRED_3WAY.md`
    - `docs/WINE11_ARM64EC_TKG_GE_WAVE6_DEFERRED_CLOSURE.md`
- the current frozen lane states remain:
  - `core-runtime = 15`
  - `loader-runtime = 9`
  - `signal-runtime = 13`
  - `server-runtime = 5`
  - `server-support = 1`
  - `wow64-support = 2`
  - `wow64-struct-support = 1`
- the just-closed freeze-recheck wave explicitly confirmed:
  - `win32u-runtime/0008` stays frozen after re-check (`window.c` / `defwnd.c` / `message.c` still
    show broad ownership drift, no safe file-local slice proven)
  - `kernelbase-runtime/0007` stays frozen (no additional safe file-local slice proven)
  - `server-runtime/0006` stays frozen after re-check (`server/process.c` / `server/thread.c` remain
    broad multi-hunk ownership drift)
  - minimal `wow64` runtime/support pair stays frozen after re-check (bridge-side changes remain
    wider than one strict pair)
  - `win32u-support` and `kernel32-support` remain deferred until a concrete runtime dependency is
    proven
- the active exact 25-step queue is now reseeded at step `1 / 25` (new wave).
- lane validation queue for the currently opened lanes is drained (`18 / 18` PASS in this checkpoint).

## Transfer Rule

Do not open a support patch just because a scope exists. A support-lane patch lands only when a
concrete runtime or bridge slice cannot land cleanly without it.
