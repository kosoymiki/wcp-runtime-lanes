Drop only isolated server-side runtime slices here.

Keep this directory empty until a patch is proven to be:

- inside `server/process.c`, `server/thread.c`, or `server/thread.h`
- clean on top of `GN + core-runtime + loader-runtime + signal-runtime`
- small enough to avoid protocol or ownership drift
