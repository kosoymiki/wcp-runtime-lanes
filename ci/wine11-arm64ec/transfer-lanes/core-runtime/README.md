# Wine11 Core Transfer Lane

This lane is the first safe transfer boundary for bringing targeted fixes from
`ValveSoftware/wine` `experimental_10.0` into our Wine 11 ARM64EC base.

Scope:

- `dlls/ntdll`
- `dlls/wow64`
- `loader`
- `server`
- `libs/wine`
- `tools/winebuild`

Rules:

- all custom patches for this lane go in `patches/`
- patches must stay inside the scoped prefixes
- the lane is always checked on top of our current unified GameNative wine patch base
- no wide `win32u`, media, shell, or graphics transfers belong here yet
