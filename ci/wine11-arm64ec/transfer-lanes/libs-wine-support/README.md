This lane carries deferred `libs/wine` support changes that may become necessary once
runtime transfer work starts depending on helper/library-side adjustments.

It sits on top of:

1. the current GameNative wine patch base
2. `core-runtime`
3. `loader-runtime`
4. `signal-runtime`
5. `server-runtime`
6. `wow64-support`

Scope:

- `libs/wine/`

Keep this lane empty until a concrete runtime or support slice needs a `libs/wine`
side change.
