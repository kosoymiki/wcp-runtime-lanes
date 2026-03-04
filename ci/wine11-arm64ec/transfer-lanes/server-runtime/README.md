This lane carries server-side runtime slices that must stay isolated from the broader
`core-runtime` lane even when they touch already-owned files.

It sits on top of:

1. the current GameNative wine patch base
2. `core-runtime`
3. `loader-runtime`
4. `signal-runtime`

Scope is limited to:

- `server/process.c`
- `server/thread.c`
- `server/thread.h`

Do not land protocol changes, request layout rewrites, or broad refcount/sync rework here
in the first pass. Keep this lane for isolated server behavior fixes only.
