# nls-po-programs-server-tools-wave1-runtime

Scope:

- `nls/`
- `po/`
- `programs/`
- `server/`
- `tools/`

Rules:

- This lane is applied only after:
  - `dlls-wave1-runtime`
  - `include-libs-wave1-runtime`
- Support-lane boundaries remain strict:
  - no back-port into earlier lane patch directories
  - no mixed ownership edits across unrelated lane scopes
- Patches in `patches/` are ordered and must apply cleanly on top of the
  prepared ownership base used by the checker.

Validation:

- `ci/wine11-arm64ec/reflect-nls-po-programs-server-tools-wave1-runtime-overlap.sh`
- `ci/wine11-arm64ec/check-nls-po-programs-server-tools-wave1-runtime-lane.sh`
- `ci/wine11-arm64ec/run-nls-po-programs-server-tools-wave1-runtime-gates.sh`
