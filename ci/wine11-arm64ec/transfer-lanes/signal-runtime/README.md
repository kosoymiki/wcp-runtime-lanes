# Wine11 Signal Runtime Transfer Lane

This lane isolates `ntdll` signal-handler work after the existing `core-runtime`
and `loader-runtime` lanes.

Scope:

- `dlls/ntdll/signal_arm64.c`
- `dlls/ntdll/signal_arm64ec.c`
- `dlls/ntdll/signal_x86_64.c`

Rules:

- all custom patches for this lane go in `patches/`
- patches must stay inside the scoped prefixes
- the lane is always checked on top of `AndreRH/wine` + the unified GameNative
  wine patch base + the current `core-runtime` + `loader-runtime` lanes
- do not mix `ntdll.spec` / `ntdll_misc.h` support changes here; they belong to
  `transfer-lanes/signal-support`
- backtrace, unwind, and context changes must stay isolated; do not merge large
  structural signal rewrites in one patch
