# Collection, variations, and memory photo — M6

M6 lets a person save recipes, make personal variations, and keep one private memory photo per entry. This document is the build contract for the M6 tracks and becomes the feature record once M6 closes.

## Decisions (Adam, 2026-09-13)

- **Photos live in the local collection database** on every platform, downscaled by the picker to about 1600 pixels on the long edge. Web has no private file system, so one storage path serves web and Android alike. Photos never enter the repository, a server, or any cloud.
- **Container object storage was considered and deferred.** A MinIO or R2-style container would move private photos off the device before accounts exist (M7), conflicts with the no-Docker working agreement, and is unreachable from an Android device on localhost. Photo access sits behind `CollectionRepository`, so a server-backed store can replace it once Docker and auth are decided.
- **Variations are full editable copies**: name, ingredients with measures, method, and notes. A variation is always presented as "Your variation of <source>" and links back; the source snapshot is never edited.
- **Separate database.** The collection uses its own drift database (`collection`), apart from the re-syncable catalog, so catalog changes can never touch personal data.
- **Out of scope:** export and backup (still an open decision), pantry persistence, accounts, sync.

## Contract (committed before the tracks start)

| File | Owner | Purpose |
| --- | --- | --- |
| `lib/features/collection/domain/collection_entry.dart` | Contract | `CollectionEntry`, `VariationDetails`, `VariationIngredient`, id generation, validation |
| `lib/features/collection/domain/memory_photo.dart` | Contract | `MemoryPhoto`, content sniffing, `PhotoRejected` |
| `lib/features/collection/data/collection_repository.dart` | Contract | Repository interface and its invariants |
| `lib/features/collection/data/memory_photo_picker.dart` | Contract | Picker interface, `PhotoSource` |
| `lib/features/collection/application/collection_providers.dart` | Contract; bodies wired at integration | Riverpod providers |
| `test/support/in_memory_collection_repository.dart` | Contract | In-memory repository, fake picker, synthetic PNGs |

Tracks may not change contract files. A needed change is reported back to the integrator instead.

## Tracks

- **Storage track.** A `CollectionDatabase` (drift, schema version 1) with an entries table and a separate photos table so list queries never load image bytes; `DriftCollectionRepository` implementing every interface invariant; `openCollectionConnection` mirroring `openCatalogConnection` with the database name `collection`; generated code committed; a shared contract suite in `test/support/collection_repository_contract.dart` run against both the drift and in-memory repositories.
- **Photo track.** The `image_picker` dependency (with its stated reason), `ImagePickerMemoryPhotoPicker` requesting about 1600 pixels and quality 85, `supportsCamera` false on web, rejection mapping to `PhotoRejected`, platform notes for Android, and tests with an injected picker function. No permission is requested before the person taps an add-photo action.
- **Screens track.** Save and "Make a variation" actions on recipe detail; `/collection` list; `/collection/:id` entry detail with the source link, photo add, replace and remove, variation edit, and delete confirmation; a variation editor for new and existing variations; a collection entry point in the page frame. Night Garden design, designed empty, loading, error, and no-photo states, reduced motion, 320-pixel and large-text readability, golden renders with the tap-target and contrast guidelines. Tests run against the in-memory repository and fake picker.
- **Gateway investigation.** Separate from M6: the `filter.php?i=Coca` 502 reported on 2026-09-13.

## Integration status (2026-09-13)

- **Gateway investigation — merged.** TheCocktailDB V2 answers a no-match ingredient with `{"drinks":"None Found"}`, which the gateway rejected as malformed. The gateway now maps exactly that string and "no data found" to the empty result; see [GATEWAY.md](GATEWAY.md). Observed with the public test key only; Adam to confirm with the paid key.
- **Photo track — merged.** `image_picker` 1.2.3 added for the platform photo picker on web and Android. `ImagePickerMemoryPhotoPicker` requests 1600 × 1600 at quality 85 and validates through `MemoryPhoto.fromBytes`. Camera capture is Android-only because web offers camera capture only through a file input's `capture` attribute, which desktop browsers ignore. Platform refusals become `PhotoPickerUnavailable` with recoverable copy. Android needs no manifest change: gallery picking uses the system photo picker and camera capture uses the camera app intent. `recoverLostPhoto()` handles Android process death mid-pick; the screens integration calls it. Device behavior (photo picker UI, camera intent, lost-data recovery) is covered by injected fakes only and still needs an on-device check.
- **Storage track — merged.** `CollectionDatabase` (schema 1) keeps an `entries` table and a separate `photos` table so lists never load image bytes. One saved entry per source is enforced by a transactional check and a partial unique index. Deleting an entry removes its photo in the same transaction. Watch streams come from drift queries. Malformed stored JSON raises a `FormatException` naming the entry. Times are stored at second precision, with ties ordered by id. The shared contract suite passes against both the drift and in-memory repositories. The web WASM path is compiled by the release web build but has no automated coverage, as with the catalog.
- **Wiring — merged.** `collectionRepositoryProvider` and `memoryPhotoPickerProvider` resolve to the real implementations. Analysis is clean, all 275 tests pass, and the release web build succeeds.
- **Screens track — merged.** Recipe detail gains a "Your collection" card: save, open saved, remove (confirmed, because it also deletes the entry's photo), and "Make a variation". Routes: `/collection` (list), `/collection/:id` (entry), `/collection/:id/edit` (edit a variation), `/discover/recipe/:id/variation` (new variation from a source). Every page's top bar has a collection button. Entries show the person's memory photo or a designed no-photo state, labeled as their own photo and never as source imagery, with add, replace, and remove; camera capture is offered only when the picker supports it. `PhotoRejected` and `PhotoPickerUnavailable` show recoverable inline copy, and cancelling changes nothing. Variations are labeled "Your variation of <source>", link to the source recipe, and list ingredients with a neutral marker plus the note that they are the person's own wording, never matched to catalog glyphs. The editor validates through the domain, enforces the limits, and confirms before discarding unsaved edits from both the back button and system back. A stored photo that fails to decode shows a designed fallback.
- **Test doubles — fixed at integration.** The contract's hand-typed one-pixel PNG failed to decode. It is replaced by `validTinyPng()`, a generated 2×2 PNG with correct checksums, and golden captures now decode images with `precacheImage` before capturing, so the photo golden shows a rendered photo.
- **Known limitation — Android lost-photo recovery is not wired.** If Android ends Zest while the photo picker or camera is open, the picked photo is not recovered, and the person picks again. `ImagePickerMemoryPhotoPicker.recoverLostPhoto()` exists, but recovering correctly needs the pending entry id to survive process death, which needs a small persisted record. That is deferred rather than wired half-way.
- **Verification.** Analysis is clean and all 294 tests pass, including goldens for the collection list, empty state, entry with photo, variation entry, and editor, with tap-target and contrast guidelines. Device checks for the Android photo picker, camera intent, and web file picker remain open.
