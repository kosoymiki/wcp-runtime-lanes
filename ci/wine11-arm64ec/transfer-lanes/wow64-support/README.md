This lane carries narrow wow64 support/declaration slices that should not be mixed into
the existing `core-runtime` lane once the bridge grows beyond simple runtime forwarders.

It sits on top of:

1. the current GameNative wine patch base
2. `core-runtime`
3. `loader-runtime`
4. `signal-runtime`
5. `server-runtime`

Scope is limited to declarations/exports that enable future wow64 runtime transfers:

- `include/winternl.h`
- `dlls/wow64/wow64.spec`

Keep this lane empty until a concrete wow64 runtime slice needs declaration or export support.
