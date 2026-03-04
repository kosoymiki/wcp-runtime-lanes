This lane carries narrow wow64 structure-side support slices that should not be mixed into
the existing `core-runtime` lane once bridge work needs 32-bit wow64 structure definitions.

It sits on top of:

1. the current GameNative wine patch base
2. `core-runtime`
3. `loader-runtime`
4. `signal-runtime`
5. `server-runtime`
6. `server-support`
7. `wow64-support`

Scope is limited to the smallest structure-side bridge changes that unblock future wow64/core transfers:

- `dlls/wow64/struct32.h`

Keep this lane empty until a concrete wow64/runtime slice needs a 32-bit bridge structure that
cannot land cleanly in `core-runtime` without widening support ownership.
