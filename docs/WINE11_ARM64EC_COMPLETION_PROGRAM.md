# Wine11 ARM64EC Completion Program

This document replaces the idea of endlessly repeating proof-only `25-step` waves.

The current `Wine11 ARM64EC` transfer block has reached a real frozen baseline:

- `core-runtime = 15`
- `loader-runtime = 9`
- `signal-runtime = 13`
- `server-runtime = 5`
- `server-support = 1`
- `wow64-support = 2`
- `wow64-struct-support = 1`

That baseline is stable and repeatedly proves through the full top-level gate chain, but repeated
`support-first` / `server-first` wave cycling no longer produces new safe slices.

## What Counts As Real Progress

From this point forward, progress must be measured only by one of these outcomes:

1. a new runtime patch lands in an existing frozen lane
2. a new support patch lands because it directly unblocks a proven runtime slice
3. ownership widens into a new library lane with its own full-spectrum plan and gate path

Repeated proof-only queue resets do not count as forward transfer progress.

## Current Blockers

The remaining blockers are structural, not procedural:

1. `server6` is blocked by wider server ownership around scheduling, object lifetime, and protocol shape.
2. the next wow64 bridge is blocked by broader API and 32-bit structure surface, not a single small helper.
3. `loader10` is blocked by substrate-level loader drift, not by one missing declaration or export.
4. `signal14` is blocked by wider unwind / exception ownership, not by an isolated file-local fix.

## Completion Mode

Completion mode has three phases.

### Phase A: Unfreeze The Core

This remains the highest-priority phase.

Real work here means:

- widen the `server` ownership boundary only where a concrete `server6` candidate can be proven
- widen the wow64 bridge only where a concrete bridge and support pair can be proven together
- open the smallest required `loader-support`, `signal-support`, or `server-support` patch only when a real blocked runtime slice requires it
- stop using proof-only wave churn as a substitute for ownership decisions

### Phase B: Build Glue And ABI Support

Once a new core/runtime widening step exists, the next ownership layer is:

- `libs/wine`
- `tools/winebuild`

These lanes stay empty until widened core/runtime work proves a concrete dependency. At that point
they move from "validated empty" to real transfer lanes.

### Phase C: Begin The Next Release Libraries

The next release-scale libraries are already known from the donor hot-file report:

- `dlls/kernelbase`
- `dlls/win32u`
- then `dlls/kernel32`

Those lanes must not be opened through blind replay. They should start only through explicit
full-spectrum plans with their own ownership boundaries, hot files, and gate expectations.

The first of those lanes is now genuinely open:

- `kernelbase-runtime`
- `kernelbase-support`

Both are now full-chain gate-proven on top of the frozen core stack.

The first six real `kernelbase-runtime` slices are now landed:

- `kernelbase-runtime/0001-file-copy-findfirstfile-reserved-fields.patch`
- `kernelbase-runtime/0002-process-delay-file-not-found-until-probe-fails.patch`
- `kernelbase-runtime/0003-debug-return-error-from-initializeprocessforwswatch.patch`
- `kernelbase-runtime/0004-debug-skip-winedbg-when-seh-logging-disabled.patch`
- `kernelbase-runtime/0005-file-use-filebothdirectoryinformation-for-findfirst.patch`
- `kernelbase-runtime/0006-debug-create-no-window-for-winedbg-spawn.patch`

`kernelbase-support` remains intentionally empty because those slices still do not require a
spec/export unblocker.

So the program has moved from "open the lane" to "grow the lane with real file-local slices and
then prove the first support dependency or explicitly keep support empty", not back into proof-only
looping.

The second deferred release lane is now also opened:

- `win32u-runtime`

It is now full-chain gate-proven on top of `kernelbase-support`, and the first seven bounded
file-local runtime slices are landed:

- `win32u-runtime/0001-sysparams-cast-sessionid-and-debugstr-fields.patch`
- `win32u-runtime/0002-window-send-notify-message-in-flashwindowex.patch`
- `win32u-runtime/0003-input-track-enable-mouse-in-pointer-state.patch`
- `win32u-runtime/0004-defwnd-cast-trace-coordinates.patch`
- `win32u-runtime/0005-defwnd-use-long-for-window-style-locals.patch`
- `win32u-runtime/0006-message-cast-low-level-hook-trace-fields.patch`
- `win32u-runtime/0007-window-cast-windowplacement-trace-fields.patch`

`dlls/win32u/vulkan.c` was explicitly re-checked and frozen for this wave, and `win32u-support`
stays deferred because no concrete runtime dependency is proven.

The third deferred release lane is now also opened:

- `kernel32-runtime`

It is full-chain gate-proven on top of `win32u-runtime` with a bounded file-local scope in:

- `dlls/kernel32/process.c`
- `dlls/kernel32/file.c`
- `dlls/kernel32/sync.c`
- `dlls/kernel32/path.c`
- `dlls/kernel32/thread.c`
- `dlls/kernel32/console.c`

`kernel32-support` remains deferred until a concrete runtime slice proves a dependency.
The first bounded `kernel32-runtime` slice is now landed:

- `kernel32-runtime/0001-process-add-wait-input-idle-fallback-wrapper.patch`
  - touches `dlls/kernel32/process.c`

`kernel32-runtime/0002` was re-checked and is explicitly frozen for now because no safe bounded
non-`process.c` slice is proven yet on the current ownership base.

The just-closed freeze-recheck wave reconfirmed:

- `kernel32-runtime/0002` stayed frozen with `no-diff` on
  `dlls/kernel32/file.c`, `dlls/kernel32/thread.c`, and `dlls/kernel32/console.c`
- `win32u-runtime/0008` stayed frozen after re-check of `window.c` / `defwnd.c` / `message.c`
  because remaining drift is broad ownership, not a safe file-local slice
- `kernelbase-runtime/0007`, `server-runtime/0006`, and minimal wow64 pair growth remained frozen
  on current ownership boundaries

## Next Real Workstreams

The next non-fake workstreams are now:

1. keep probing `kernel32-runtime/0002` through function-level ownership carving in
   `file.c` / `thread.c` / `console.c` instead of replaying full-file drift
2. keep probing `win32u-runtime/0008` through bounded zones in `window.c` / `defwnd.c` / `message.c`
   and only land if one zone is demonstrably safe file-local
3. keep `kernelbase-runtime/0007` in revive mode only through bounded candidates in
   `process.c` / `file.c` / `debug.c`; keep `kernelbase-support` empty until a hard dependency appears
4. keep `server-runtime/0006` and minimal wow64 pair in strict ownership-carve mode; land only if a
   protocol-free / header-local candidate is proven with clean gates

## Rule

If a `25-step` wave closes without any new runtime or support patch, the next action must be one of:

- widen ownership in a blocked frozen lane
- open a new deferred library full-spectrum plan
- refresh the top-level completion program

It must not be another identical proof-only loop presented as progress.
