# Zest backend — intentionally empty

There is no backend yet, by design. The decisions that create one are deliberately deferred:

- **Recipe data:** the app calls TheCocktailDB directly from the client using its documented public test key (personal/educational use). No proxy, no server-side key, no database to copy into. Client-side response caching keeps within rate limits.
- **Search:** all discovery, matching, and constellation computation run on-device against cached data. A graph of a few hundred ingredients is trivially a client workload.
- **Auth and sync:** the only features that genuinely want a backend are accounts and cross-device sync, and those are the M7 milestone — gated on Adam choosing an approach (Supabase, Firebase, or local-first with an account later). Until then the app is local-first: `shared_preferences`/`drift` on device, photos in app-private storage.

When M7's decision lands, this folder gets the chosen shape (e.g. Supabase schema/migrations, or a small service). Until then: do not scaffold, do not add a "temporary" API server, do not move TheCocktailDB calls behind a proxy.
