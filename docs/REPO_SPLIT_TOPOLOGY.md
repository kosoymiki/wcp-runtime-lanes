# Repo Split Topology

Final split model for Ae.solator delivery lanes.

## Repositories

- `kosoymiki/aesolator`
  - Application repository (APK/UI/runtime binding layer).
- `kosoymiki/freewine11`
  - Native FreeWine source tree.
- `kosoymiki/wcp-runtime-lanes` (**WCP Archive**)
  - Canonical archive release host for:
    - `aesolator-latest` (APK lane built from `kosoymiki/aesolator`)
    - `freewine11-arm64ec-latest`
    - `dxvk-gplasync-latest`
    - `dxvk-gplasync-arm64ec-latest`
    - `vkd3d-proton-latest`
    - `vkd3d-proton-arm64ec-latest`
    - `vulkan-sdk-arm64-latest`
    - `vulkan-sdk-x86_64-latest`
    - `dgvoodoo-x86_64-latest`
    - `dgvoodoo-arm64ec-latest`
- `kosoymiki/wcp-graphics-lanes`
  - Graphics build/control repository.
  - Canonical release host for graphics ZIP lanes:
    - `aeturnip-arm64-latest`
    - `aeopengl-driver-arm64-latest`
  - Build owner for dgVoodoo archive lane:
    - `dgvoodoo-x86_64-latest` (`dgvoodoo-x86_64.wcp` published to `wcp-runtime-lanes`)
    - `dgvoodoo-arm64ec-latest` (`dgvoodoo-arm64ec.wcp` published to `wcp-runtime-lanes`)
- `kosoymiki/winlator-wine-proton-arm64ec-wcp`
  - Legacy monorepo; archived migration history only.
  - Must not be used as active source-of-truth for release routing.

## Contract Rules

1. Package metadata must point to actual release host (`sourceRepo`) per lane.
2. Aesolator APK lane publishes into WCP Archive under `aesolator-latest`.
3. DXVK/VKD3D/VulkanSDK WCP lanes publish into WCP Archive.
4. Turnip/OpenGL ZIP lanes publish from graphics repo; dgVoodoo publishes as WCP via archive.
5. Legacy monorepo release tags are not part of active topology.

## Status

- Split is active and enforced in CI/workflows.
- Documentation is aligned with release ownership.
