# Mainline Project State (WCP Archive)

Snapshot date: 2026-03-10

## Scope

- This repo is the canonical **WCP Archive** host.
- Native APK lane built here: `aesolator-latest`.
- Native runtime lane built here: `freewine11-arm64ec-latest`.
- Additional WCP lanes hosted here from split graphics CI:
  - `dxvk-gplasync*`
  - `vkd3d-proton*`
  - `vulkan-sdk-*`
  - `dgvoodoo-x86_64-latest`
  - `dgvoodoo-arm64ec-latest`

## Current Build Contract

- Runtime source mode: `freewine-git`.
- Source repository: `kosoymiki/freewine11` (private).
- Runtime product line: `FreeWine 11`.
- Runtime target policy: Android bionic-only.
- Validation gate: `ci/validation/inspect-wcp-runtime-contract.sh --strict-bionic --require-usb`.
- Legacy transfer/rebase scripts are removed from mainline runtime lane.
- Local scratch mirror `wine-src` is a disposable build mirror only and must not
  be treated as a second source-of-truth.

## CI Status

- Workflow: `.github/workflows/ci-aesolator-apk.yml`.
- Workflow: `.github/workflows/ci-arm64ec-wine.yml`.
- Source access is now resolved in a dedicated step (`Resolve FreeWine clone URL`)
  with explicit preflight (`git ls-remote`) and actionable error output.
- Clone helper `ci/runtime-sources/local-source-layout.sh` now keeps clone/fetch
  diagnostics visible and uses filtered clone fallback to plain clone.

## Required Secrets

- `AEO_RELEASE_TOKEN` (required for production CI):
  - read: `kosoymiki/aesolator`
  - read: `kosoymiki/freewine11`
  - write: `kosoymiki/wcp-runtime-lanes` releases
- Optional:
  - `AESOLATOR_REPO_URL`
  - `FREEWINE11_REPO_URL`
  - `AEOLATOR_PREFIX_PACK_URL`

## Open Items

1. Keep `AEO_RELEASE_TOKEN` present in repo secrets; otherwise runtime CI cannot
   read private FreeWine source.
2. Continue runtime forensic/provenance export evolution in lockstep with
   `aesolator` issue-bundle schema.
3. Keep documentation aligned with the actual split model:
   - `freewine11` owns runtime source
   - `aeolator` owns app source
   - `wcp-runtime-lanes` owns packaging/release orchestration
