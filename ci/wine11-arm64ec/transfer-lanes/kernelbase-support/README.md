This lane carries deferred `kernelbase` support changes that may become necessary
once a concrete `kernelbase-runtime` slice proves a spec/header dependency.

It sits on top of:

1. the current GameNative wine patch base
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

Scope:

- `dlls/kernelbase/kernelbase.spec`
- `dlls/kernelbase/`

Keep this lane empty until a concrete `kernelbase-runtime` slice needs a
declaration/export-side change.
