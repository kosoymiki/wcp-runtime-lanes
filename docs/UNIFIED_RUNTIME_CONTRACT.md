# Unified Runtime Contract

## Scope

Mainline runtime contract for `wcp-runtime-lanes` (WCP Archive) in FreeWine-only mode.

## Mainline Invariants

1. Runtime source is FreeWine (`WCP_WINE_SOURCE_MODE=freewine-git|freewine-local`).
2. Target class is Android bionic (`WCP_RUNTIME_CLASS_TARGET=bionic-native`).
3. CI runtime gate is mandatory before release publish:
   - `ci/validation/inspect-wcp-runtime-contract.sh --strict-bionic --require-usb`.
4. USB support is mandatory in runtime payload (`WCP_REQUIRE_USB_RUNTIME=1`).
5. Mainline does not apply external patchsets during runtime package build (`WCP_GN_PATCHSET_ENABLE=0`).

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
- External baseline diff gates.

These belong to archive/research lanes and must not be required for `main` release workflow.
