# WCP Runtime Lanes

Runtime packaging repository for Aeolator.

## Scope

- Build FreeWine-based runtime package `freewine11-arm64ec.wcp`.
- Publish runtime release lane `freewine11-arm64ec-latest`.
- Keep runtime contract and forensic hooks aligned with Android bionic-only policy.

## Inputs / Outputs

- Source input: `kosoymiki/freewine11` (private native source tree).
- Package output: `kosoymiki/wcp-runtime-lanes` GitHub Releases.
- Consumer: `kosoymiki/aeolator` app (Contents manager).

## Main Workflow

- `.github/workflows/ci-arm64ec-wine.yml`
  - builds runtime from FreeWine source,
  - validates runtime contract,
  - publishes WCP artifact to this repo.

## CI Secrets

- `AEO_RELEASE_TOKEN` (required)
  - must have read access to `kosoymiki/freewine11` (private source repo),
  - must have write access to `kosoymiki/wcp-runtime-lanes` releases.
- `FREEWINE11_REPO_URL` (optional)
  - override source URL for FreeWine clone if needed.
- `AEOLATOR_PREFIX_PACK_URL` (optional)
  - override prefix pack URL for runtime packaging.

## Local Run

```bash
bash build.sh
```

## Docs

- `docs/REPO_SPLIT_TOPOLOGY.md`
- `docs/UNIFIED_RUNTIME_CONTRACT.md`
- `docs/LOCAL_SOURCE_LAYOUT.md`
- `docs/MAINLINE_PROJECT_STATE.md`
