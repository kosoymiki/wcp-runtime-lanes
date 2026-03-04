# Mainline Project State (Runtime Lanes)

Snapshot date: 2026-03-04

## Scope

- This repo owns only FreeWine runtime package lanes.
- Active lane: `freewine11-arm64ec-latest`.
- Artifact host: `kosoymiki/wcp-runtime-lanes` releases.

## Current Build Contract

- Runtime source mode: `freewine-git`.
- Source repository: `kosoymiki/freewine11` (private).
- Runtime target policy: Android bionic-only.
- Validation gate: `ci/validation/inspect-wcp-runtime-contract.sh --strict-bionic`.

## CI Status

- Workflow: `.github/workflows/ci-arm64ec-wine.yml`.
- Source access is now resolved in a dedicated step (`Resolve FreeWine clone URL`)
  with explicit preflight (`git ls-remote`) and actionable error output.
- Clone helper `ci/runtime-sources/local-source-layout.sh` now keeps clone/fetch
  diagnostics visible and uses filtered clone fallback to plain clone.

## Required Secrets

- `AEO_RELEASE_TOKEN` (required for production CI):
  - read: `kosoymiki/freewine11`
  - write: `kosoymiki/wcp-runtime-lanes` releases
- Optional:
  - `FREEWINE11_REPO_URL`
  - `AEOLATOR_PREFIX_PACK_URL`

## Open Items

1. Keep `AEO_RELEASE_TOKEN` present in repo secrets; otherwise runtime CI cannot
   read private FreeWine source.
2. Continue runtime forensic/provenance export evolution in lockstep with
   `aeolator` issue-bundle schema.

