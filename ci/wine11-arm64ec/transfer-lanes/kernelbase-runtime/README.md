This lane carries the first deferred non-core runtime slices after the frozen
`ntdll / wow64 / loader / signal / server` block.

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

Initial scope is limited to:

- `dlls/kernelbase/process.c`
- `dlls/kernelbase/file.c`
- `dlls/kernelbase/debug.c`

Do not widen this lane into broad directory ownership, mixed `kernel32 + kernelbase`
refactors, or large process/file rewrites in the first pass. Keep it for isolated
runtime behavior fixes only.
