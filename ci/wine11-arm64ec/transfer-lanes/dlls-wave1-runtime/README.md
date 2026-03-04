# Wine11 ARM64EC DLLs Wave1 Runtime Lane

This lane carries the fourth deferred non-core runtime wave after `kernelbase`,
`win32u`, and `kernel32`.

It sits on top of:

1. the current GameNative wine patch base
2. `core-runtime`
3. `loader-runtime`
4. `signal-runtime`
5. `signal-support`
6. `server-runtime`
7. `server-support`
8. `wow64-support`
9. `wow64-struct-support`
10. `libs-wine-support`
11. `winebuild-support`
12. `kernelbase-runtime`
13. `kernelbase-support`
14. `win32u-runtime`
15. `kernel32-runtime`

Initial scope was the requested donor DLL bundle:

- `dlls/acledit`
- `dlls/aclui`
- `dlls/activeds`
- `dlls/activeds.tlb`
- `dlls/actxprxy`
- `dlls/adsldp`
- `dlls/adsldpc`
- `dlls/advapi32`
- `dlls/advpack`
- `dlls/amd_ags_x64`
- `dlls/amdxc64`
- `dlls/amsi`
- `dlls/amstream`
- `dlls/apisetschema`
- `dlls/apphelp`
- `dlls/appwiz.cpl`
- `dlls/appxdeploymentclient`
- `dlls/atiadlxx`
- `dlls/atl`
- `dlls/atl80`
- `dlls/atl90`
- `dlls/atl100`
- `dlls/atl110`
- `dlls/atlthunk`
- `dlls/atmlib`
- `dlls/audioses`
- `dlls/authz`
- `dlls/avicap32`
- `dlls/avifil32`
- `dlls/avifile.dll16`
- `dlls/avrt`
- `dlls/bcp47langs`
- `dlls/bcrypt`

Current scope is widened for high-throughput transfer mode to `dlls/` (full
DLL tree), including the next donor block requested after `bcrypt` (starting
from `bcryptprimitives`, `bluetoothapis`, `browseui`, `bthprops.cpl`,
`cabinet`, `capi2032`, `cards`, `cdosys`, `cfgmgr32`, ...).

Keep slices file-local and reversible; postpone heavy integration/debug cycles
to dedicated combined validation passes.
