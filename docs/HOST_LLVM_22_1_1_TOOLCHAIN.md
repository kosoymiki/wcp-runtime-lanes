# Host LLVM 22.1.1

This repository owns the canonical GitHub Actions/release lane for the Android
ARM64 host `LLVM 22.1.1` toolchain used by local `Ae.solator` / Termux builds.

## Scope

- host-only toolchain
- not part of `imagefs`
- not packaged into the APK
- intended for local Android/Termux builds and later `wine` compilation

## Release Contract

- workflow: `.github/workflows/ci-host-llvm-toolchain.yml`
- build script: `ci/toolchains/build-host-llvm-android.sh`
- release tag: `host-llvm-22.1.1`
- asset: `llvm-22.1.1-termux-android-aarch64.tar.zst`

## Consumer Repos

Consumer repos such as `aeolator` should fetch the release asset from
`wcp-runtime-lanes` and use it as the preferred host compiler lane instead of
owning a duplicate heavy CI workflow.
