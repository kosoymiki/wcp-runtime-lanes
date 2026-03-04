# documentation-fonts-root-wave1-runtime

Scope:

- `documentation/`
- `fonts/`
- `aclocal.m4`
- `ANNOUNCE.md`
- `AUTHORS`
- `autogen.sh`
- `configure.ac`
- `COPYING.LIB`
- `LICENSE`
- `LICENSE.OLD`
- `MAINTAINERS`
- `README.esync`
- `README.md`
- `VERSION`

Rules:

- This lane is applied only after:
  - `nls-po-programs-server-tools-wave1-runtime`
- Support-lane boundaries remain strict:
  - no back-port into earlier lane patch directories
  - no mixed ownership edits across unrelated lane scopes
- Patches in `patches/` are ordered and must apply cleanly on top of the
  prepared ownership base used by the checker.

Validation:

- `ci/wine11-arm64ec/reflect-documentation-fonts-root-wave1-runtime-overlap.sh`
- `ci/wine11-arm64ec/check-documentation-fonts-root-wave1-runtime-lane.sh`
- `ci/wine11-arm64ec/run-documentation-fonts-root-wave1-runtime-gates.sh`
