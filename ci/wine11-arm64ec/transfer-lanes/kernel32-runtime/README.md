This lane carries the third deferred non-core runtime slices after `kernelbase`
and `win32u`.

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
13. `kernelbase-support`
14. `win32u-runtime`

Initial scope is limited to:

- `dlls/kernel32/process.c`
- `dlls/kernel32/file.c`
- `dlls/kernel32/sync.c`
- `dlls/kernel32/path.c`
- `dlls/kernel32/thread.c`
- `dlls/kernel32/console.c`

Do not widen this lane into broad directory ownership, `tests/` imports, or mixed
`kernel32 + kernelbase + win32u + server` ownership grabs. Keep it for isolated
runtime behavior fixes only.
