# Local Source Layout

`wcp-runtime-lanes` mainline CI owns two lanes:
- Aesolator APK archive lane (`ci-aesolator-apk.yml`)
- FreeWine runtime WCP lane (`ci-arm64ec-wine.yml`)

Active local source anchors:

- `/home/mikhail/wcp-sources/aeolator`
  - source seed for Aesolator APK lane
  - cloned by CI into isolated workspace (`aesolator-src`)
- `/home/mikhail/wcp-sources/freewine11`
  - primary local seed for `WCP_WINE_SOURCE_MODE=freewine-local`
  - fallback seed for `WCP_WINE_SOURCE_MODE=freewine-git` clone acceleration

Policy:

- APK release workflow (`.github/workflows/ci-aesolator-apk.yml`) consumes only Aesolator source.
- Runtime release workflow (`.github/workflows/ci-arm64ec-wine.yml`) consumes only FreeWine source.
- Historical Proton/GameNative transfer scaffolds are out of mainline scope.
- Any experimental research work must live in a dedicated archive/research lane, not in this repo mainline.
