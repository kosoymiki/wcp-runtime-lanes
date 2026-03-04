# WCP Archive

Canonical WCP archive repository for Ae.solator package lanes.

Repository slug stays `wcp-runtime-lanes`, but product role is **WCP Archive**.

## Scope

- Build and publish FreeWine runtime WCP:
  - `freewine11-arm64ec.wcp`
  - release tag `freewine11-arm64ec-latest`
- Host translation/runtime-support WCP lanes produced by split CI:
  - DXVK GPLAsync (`dxvk-gplasync*`)
  - VKD3D-Proton (`vkd3d-proton*`)
  - Vulkan SDK (`vulkan-sdk-*`)
  - dgVoodoo (`dgvoodoo-x86_64-latest`, `dgvoodoo-arm64ec-latest`)
- Keep runtime/forensic contracts strict for bionic-only deployment.

## Ownership Model

- Source tree: `kosoymiki/freewine11`
- Archive host: `kosoymiki/wcp-runtime-lanes`
- App consumer: `kosoymiki/aesolator`
- Graphics ZIP producer + dgVoodoo build owner: `kosoymiki/wcp-graphics-lanes`

## Main Workflow

- `.github/workflows/ci-arm64ec-wine.yml`
  - builds FreeWine runtime package
  - enforces strict runtime + forensic contract
  - publishes runtime package to WCP Archive releases
- mainline CI does not depend on donor patch/rebase lanes.

## CI Secrets

- `AEO_RELEASE_TOKEN` (required)
  - read access to `kosoymiki/freewine11`
  - write access to `kosoymiki/wcp-runtime-lanes` releases
- `FREEWINE11_REPO_URL` (optional)
- `AEOLATOR_PREFIX_PACK_URL` (optional)

## Local Run

```bash
bash build.sh
```

## Docs

- `docs/REPO_SPLIT_TOPOLOGY.md`
- `docs/UNIFIED_RUNTIME_CONTRACT.md`
- `docs/LOCAL_SOURCE_LAYOUT.md`
- `docs/MAINLINE_PROJECT_STATE.md`
