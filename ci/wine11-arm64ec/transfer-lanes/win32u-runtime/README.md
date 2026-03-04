# Wine11 ARM64EC Win32u Runtime Lane

Purpose:

- hold the first bounded runtime transfer slices in `dlls/win32u` after `kernelbase`
- keep ownership file-local while the frozen core block remains unchanged

Current scope is intentionally runtime-only:

- `dlls/win32u/sysparams.c`
- `dlls/win32u/window.c`
- `dlls/win32u/input.c`
- `dlls/win32u/message.c`
- `dlls/win32u/defwnd.c`
- `dlls/win32u/vulkan.c`

Do not place spec/header patches in this lane.
If a runtime slice needs export/header work, open `win32u-support` as a separate lane.

