# Wine11 Aeolator Bionic-Only Runtime Lane

This lane hardens Android runtime startup in `freewine11` for Aeolator by
enforcing a native bionic-only environment at loader init time.

Current lane focus:

- bionic-only env enforcement (`AEO_BIONIC_ONLY_ACTIVE`, glibc path sanitization)
- Android arm64 autotune matrix at JNI entry:
  - profile set: `conservative` / `balanced` / `aggressive`
  - SoC-class mapping: `entry -> conservative`, `mid-range -> balanced`, `high-end -> aggressive`
  - explicit override via `AEO_ARM64_TUNE_PROFILE` (`auto` keeps SoC mapping)
- forensic runtime markers for SoC class, requested/effective profile and matrix metadata (`AEO_ARM64_*`)

Scope:

- `dlls/ntdll/unix/loader.c`

Rules:

- apply only on top of the current runtime stack through `dlls-wave1-runtime`
- keep lane limited to runtime env sanitization and forensic runtime markers
- avoid pulling unrelated loader refactors into this lane
