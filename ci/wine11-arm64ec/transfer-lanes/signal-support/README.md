# Wine11 Signal Support Transfer Lane

This is the preparatory lane for signal-adjacent declarations and exports that
must stay separate from the runtime signal handlers.

Scope:

- `dlls/ntdll/ntdll.spec`
- `dlls/ntdll/ntdll_misc.h`

Rules:

- keep this lane empty until a concrete signal runtime slice needs it
- any patch here must immediately unblock a specific `signal-runtime` patch
- no speculative declarations, exports, or debug helpers
