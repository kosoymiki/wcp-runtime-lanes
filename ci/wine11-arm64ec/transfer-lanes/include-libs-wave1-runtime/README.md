This lane carries the next deferred transfer wave after `dlls-wave1-runtime`,
focused on:

- `include/`
- `libs/`

It sits on top of:

1. the current GameNative wine patch base
2. `core-runtime`
3. `loader-runtime`
4. `signal-runtime`
5. `server-runtime`
6. `server-support`
7. `wow64-support`
8. `wow64-struct-support`
9. `libs-wine-support`
10. `winebuild-support`
11. `kernelbase-runtime`
12. `kernelbase-support`
13. `win32u-runtime`
14. `kernel32-runtime`
15. `dlls-wave1-runtime`

Scope is transfer-first over `include/` and `libs/`, while preserving existing
lane ownership boundaries.

Do not re-own already assigned support files from earlier lanes. In particular:

- `include/winternl.h` remains owned by `wow64-support`.

Use `exclude-paths.txt` for explicit ownership exclusions.
