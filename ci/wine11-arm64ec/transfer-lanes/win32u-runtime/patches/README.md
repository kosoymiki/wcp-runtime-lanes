# Win32u Runtime Patches

Put only file-local `dlls/win32u/*.c` runtime slices here.

Rules:

- one isolated behavior fix per patch
- patch must apply after `kernelbase-support`
- no `win32u.spec` or private header edits in this lane
- no mixed `user32 + win32u + server` ownership merges

