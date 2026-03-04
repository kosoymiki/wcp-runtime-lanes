# Local Source Layout

`wcp-runtime-lanes` is now FreeWine-only in mainline CI.

Active local source anchors:

- `/home/mikhail/wcp-sources/freewine11`
  - primary local seed for `WCP_WINE_SOURCE_MODE=freewine-local`
  - fallback seed for `WCP_WINE_SOURCE_MODE=freewine-git` clone acceleration
- `/home/mikhail/wcp-sources/andre-wine11-arm64ec`
  - optional donor/reference checkout, not used directly by runtime CI workflow
- `/home/mikhail/wcp-sources/valve-wine-experimental10`
  - optional donor/reference checkout, not used directly by runtime CI workflow

Policy:

- Runtime release workflow (`.github/workflows/ci-arm64ec-wine.yml`) consumes only FreeWine source.
- Historical Proton/GameNative transfer scaffolds are out of mainline scope.
- Any experimental donor work must live in a dedicated archive/research lane, not in this repo mainline.
