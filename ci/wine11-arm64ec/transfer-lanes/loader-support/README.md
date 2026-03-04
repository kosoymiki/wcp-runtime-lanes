# Wine11 Loader Support Transfer Lane

This is the preparatory lane for loader-adjacent declarations and exports that
must stay separate from the runtime `loader.c` slices.

Scope:

- `dlls/ntdll/ntdll.spec`
- `dlls/ntdll/ntdll_misc.h`

Rules:

- keep this lane empty until a concrete runtime slice cannot apply cleanly
  without a matching export or declaration
- no cosmetic declaration syncs
- any patch here must directly unblock the next `loader-runtime`, `wow64`, or
  `signal` slice
