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
