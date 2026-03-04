# Wine11 Loader Runtime Transfer Lane

This lane isolates `dlls/ntdll/unix/loader.c` work after the broader
`core-runtime` lane has already been applied.

Scope:

- `dlls/ntdll/unix/loader.c`

Rules:

- all custom patches for this lane go in `patches/`
- patches must stay inside the scoped prefixes
- the lane is always checked on top of `AndreRH/wine` + the unified GameNative
  wine patch base + the current `core-runtime` lane
- `dlls/ntdll/ntdll.spec` and `dlls/ntdll/ntdll_misc.h` do not belong here;
  they move through `transfer-lanes/loader-support` only when a loader/runtime
  slice immediately requires them
