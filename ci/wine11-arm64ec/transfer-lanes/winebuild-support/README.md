This lane carries deferred `tools/winebuild` changes that may become necessary once
runtime transfer work depends on build-side symbol or thunk generation adjustments.

It sits on top of:

1. the current GameNative wine patch base
2. `core-runtime`
3. `loader-runtime`
4. `signal-runtime`
5. `server-runtime`
6. `wow64-support`
7. `libs-wine-support`

Scope:

- `tools/winebuild/`

Keep this lane empty until a concrete upstream transfer requires `winebuild` changes.
