# Local Source Layout

The main repository now uses a stable sibling source root at `/home/mikhail/wcp-sources` for long-lived upstream caches and editable build trees. This avoids rebuilding each Wine/Proton lane from ad-hoc temporary clones.

Current persistent paths:

- `/home/mikhail/wcp-sources/andre-wine11-arm64ec`
  AndreRH `wine` local anchor, checked out on `arm64ec`. This is the long-lived Wine 11 ARM64EC base for future Proton 11 work.
- `/home/mikhail/wcp-sources/valve-wine-experimental10`
  Local anchor for `ValveSoftware/wine` on `experimental_10.0`. This is the donor/reference side for reflective transfer into our Wine 11 ARM64EC lane.
- `/home/mikhail/wcp-sources/proton-ge-upstream`
  Full `GloriousEggroll/proton-ge-custom` cache with all heads/tags fetched. Use this as the seed repo for GE source trees.
- `/home/mikhail/wcp-sources/proton-ge-linked-wine11`
  Detached GE working tree anchored on `GE-Proton10-32`, with `wine -> active Wine11 tree`.
  Active target is resolved by layout helper:
  - prefer `/home/mikhail/wcp-sources/freewine11`
  - fallback `/home/mikhail/wcp-sources/andre-wine11-arm64ec`
- `/home/mikhail/wcp-sources/gamenative-proton`
  Full `GameNative/proton-wine` cache, checked out on `bleeding-edge`, with all branches fetched.
- `/home/mikhail/wcp-sources/proton11-ae-stack`
  Aggregate path for the future Proton 11 custom lane:
  `wine11-arm64ec` (active), `wine11-donor`, `proton-ge`, `gamenative-proton`.
- `/home/mikhail/wcp-sources/proton11-ge-arm64ec`
  Editable scaffold for the future Proton 11 GE Arm64EC lane. This is a skeleton only:
  owned directories + `refs/` links to the upstream anchors.
  It now also receives a synced transfer patch-base from this repo:
  - `patches/wine11-arm64ec-transfer-lanes/`
  - `manifests/wine11-arm64ec-transfer-lanes.tsv`
  - `manifests/wine11-dlls-wave1-patch-index.tsv`
  It can also receive a synced native full tree snapshot:
  - `native/freewine11/`
  - `refs/wine11-native -> native/freewine11`
  - `manifests/freewine11-native-sync.env`
- `/home/mikhail/wcp-sources/freewine11`
  Our owned Wine tree (`freewine11-main`) built from `andre-wine11-arm64ec` with the
  full accepted transfer stack (GN baseline + Valve-derived lanes + TKG-GE Wave6 runtime)
  and local provenance metadata in `.freewine11/provenance/`.
  This is now the default active native tree for runtime links.

Operational rule:

- Do not treat these paths as disposable temp trees.
- Refresh them via `ci/runtime-sources/bootstrap-local-source-layout.sh`.
- CI/build helpers should prefer these repositories as local git seeds and still fetch the requested ref from the real upstream remote.
- Refresh the scaffolded Wine11 lane patch-base with:
  - `bash ci/proton11-ge-arm64ec/sync-wine11-transfer-patch-base.sh`
- Rebuild/update the owned `freewine11` tree with:
  - `bash ci/wine11-arm64ec/build-freewine11-tree.sh`
- Promote/relink full native tree in one command:
  - `bash ci/wine11-arm64ec/promote-freewine11-native-tree.sh`
- Sync full native tree into Proton11 scaffold:
  - `bash ci/proton11-ge-arm64ec/sync-freewine11-native-tree.sh`

This layout is intentionally separate from `work/` so the main repository can keep one global patch base while Wine/Proton source trees stay individualized per package.
