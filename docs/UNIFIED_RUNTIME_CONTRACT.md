# Unified Runtime Contract

## Scope

Mainline runtime contract for `wcp-runtime-lanes` (WCP Archive) in FreeWine-only mode.

## Mainline Invariants

1. Runtime source is FreeWine (`WCP_WINE_SOURCE_MODE=freewine-git|freewine-local`).
2. Target class is Android bionic (`WCP_RUNTIME_CLASS_TARGET=bionic-native`).
3. CI runtime gate is mandatory before release publish:
   - `ci/validation/inspect-wcp-runtime-contract.sh --strict-bionic --require-usb`.
4. USB support is mandatory in runtime payload (`WCP_REQUIRE_USB_RUNTIME=1`).
5. Mainline does not apply donor patchsets during runtime package build (`WCP_GN_PATCHSET_ENABLE=0`).

## Required Provenance Outputs

Every successful runtime build must produce:

- `${WCP_NAME}.wcp`
- `SHA256SUMS`
- `out/freewine11/logs/runtime-provenance.env`
- `share/wcp-forensics/unix-module-abi.tsv` inside WCP
- `share/wcp-forensics/bionic-source-entry.json` inside WCP

## Runtime Fallback Rules

1. External translation/runtime layers (FEX/Box) are treated as external-only policy inputs.
2. Vulkan runtime fallback may move to system Vulkan only on explicit probe/init failure.
3. Any policy fallback must preserve forensic markers and deterministic reason codes.

## Out Of Scope For Mainline

- Proton/GameNative transfer-lane automation.
- Patch-batch/rebase scaffolds.
- Donor-baseline diff gates.

These belong to archive/research lanes and must not be required for `main` release workflow.
- `AERO_DX8_D8VK_EXTRACTED`
- `AERO_DX_POLICY_STACK`
- `AERO_DX_POLICY_REASON`
- `AERO_DX_POLICY_ORDER`
- `AERO_DXVK_ARTIFACT_SOURCE`
- `AERO_VKD3D_ARTIFACT_SOURCE`
- `AERO_DDRAW_ARTIFACT_SOURCE`
- `AERO_LAUNCH_GRAPHICS_PACKET`
- `AERO_LAUNCH_GRAPHICS_PACKET_SHA256`
- `AERO_UPSCALE_RUNTIME_MATRIX`

Upscaler resolution must emit:

- `UPSCALE_PROFILE_RESOLVED`
- `UPSCALE_MEMORY_POLICY_APPLIED`
- `UPSCALE_MODULE_APPLIED`
- `UPSCALE_MODULE_SKIPPED`
- `DX_WRAPPER_GRAPH_RESOLVED`
- `DX_WRAPPER_ARTIFACTS_APPLIED`
- `LAUNCH_GRAPHICS_PACKET_READY`
- `DXVK_CAPS_RESOLVED`
- `PROTON_FSR_HACK_RESOLVED`
- `UPSCALE_RUNTIME_MATRIX_READY`
- `UPSCALE_LIBRARY_LAYOUT_APPLIED`
- `RUNTIME_LIBRARY_CONFLICT_SNAPSHOT`
- `RUNTIME_LIBRARY_CONFLICT_DETECTED`
- `RUNTIME_SUBSYSTEM_SNAPSHOT`
- `RUNTIME_LOGGING_CONTRACT_SNAPSHOT`
- `RUNTIME_LIBRARY_COMPONENT_SIGNAL`
- `RUNTIME_LIBRARY_COMPONENT_CONFLICT`

## Evidence Requirement

Each accepted change must be linked in `docs/REFLECTIVE_HARVARD_LEDGER.md` with:

- hypothesis
- evidence
- counter-evidence
- decision
- verification logs/tests

## ADB Contour Requirement

When collecting device evidence (`forensic-adb-runtime-contract.sh` or
`forensic-adb-harvard-suite.sh`), runtime logging contract coverage must be
captured as:

- per-scenario:
  - `logcat-runtime-conflict-contour.txt`
  - `runtime-conflict-contour.summary.txt`
- suite-level:
  - `runtime-conflict-contour.tsv`
  - `runtime-conflict-contour.md`
  - `runtime-conflict-contour.json`
  - `runtime-conflict-contour.summary.txt`

Conflict severity gating is controlled by
`WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE=off|info|low|medium|high`.
