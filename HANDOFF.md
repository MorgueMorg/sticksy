# Sticksy — what changed and what to run

I could not compile here (no Flutter SDK in my sandbox and no network to fetch
one), so everything below was written by inspection. Run the two commands in
step 1 first and send me anything red — I'll fix it immediately.

## 1. Run this first

```bash
flutter pub get
flutter analyze
flutter test
flutter run                 # debug
flutter build apk --release # the build that used to crash
```

`pubspec.yaml` changed (`flutter_dotenv` removed, `.env` no longer bundled), so
`flutter pub get` is required before anything else.

## 2. The bugs that were breaking it

### Release crash / "AI doesn't work"

`android/app/src/main/AndroidManifest.xml` had **no `INTERNET` permission**. It
existed only in `src/debug/` and `src/profile/`, which Flutter generates for
you. So every network call worked in `flutter run` and was refused by the OS in
release. Added `INTERNET` + `ACCESS_NETWORK_STATE` to the main manifest.

Also in `android/app/build.gradle.kts`:

- Code shrinking is now **explicitly off** (`isMinifyEnabled = false`,
  `isShrinkResources = false`). R8 stripping drift/sqlite3 reflection is the
  other classic release-only crash. `proguard-rules.pro` now exists with the
  right keep rules, so turning it back on later is a one-line change.
- Release signing reads `android/key.properties` if present and falls back to
  the debug key, so `flutter build apk --release` always produces something
  installable.

### The API key was empty

`.env` shipped with `OPENROUTER_API_KEY=` blank, and it was bundled as a Flutter
asset. Two problems: AI could never work, and a `.env` parse failure at startup
put a blocking error screen in front of the app.

`.env` and `flutter_dotenv` are gone. Keys now live in **Settings → AI**,
stored in `SharedPreferences`, editable without a rebuild, with a **Test
connection** button that tells you exactly what's wrong (bad key, no credit,
rate limited, wrong model id).

### Crash when creating a pack (fixed after your first run)

```
A TextEditingController was used after being disposed.
A RenderFlex overflowed by 99448 pixels on the bottom.
'attached': is not true.
```

All three were one bug. `promptForText` created the controller in the calling
function and disposed it in a `finally` after `await showModalBottomSheet`. That
future resolves the instant `Navigator.pop` runs — but the sheet keeps
rebuilding for the whole 250ms dismiss animation, so the next frame built a
`TextField` around a dead controller. The exception during build is what
produced the nonsense overflow number and the `!attached` assertion.

Controllers are now owned by a `State` (`_TextPromptSheet`, `_TextLayerSheet`)
and disposed in `State.dispose()`, which fires after the route is gone. The
editor's text sheet had the identical pattern and got the same treatment.

Separately, `SheetSurface` was asking for 88% of the **full** screen height
while *also* padding its bottom by `viewInsets.bottom` — with the keyboard up
that's more room than exists. It now budgets against the space actually
available and scrolls its body by default, so no sheet can overflow.

### The editor barely worked

- Every layer was wrapped in `Positioned.fill`, giving each one a **full-canvas
  hit area**. Only the topmost layer could ever be tapped or dragged. Layers are
  now `Center` + intrinsic size, so hit testing lands on the actual artwork.
- Drag used `details.focalPoint` in **screen** pixels while the canvas is drawn
  through `Transform.scale`, so the sticker ran away from your finger. Deltas
  are now divided by the display scale.
- `copyWith` used `value ?? this.value` for `selectedLayerId`, which made `null`
  unreachable — tapping empty canvas never deselected. Fixed with a sentinel.
- **The transparency checkerboard was rasterised into every exported sticker.**
  The canvas now renders in a "clean" mode during capture: no checkerboard, no
  selection outline, no rounded corners.
- Export size was whatever the device pixel ratio happened to be. Now always
  512×512 with real alpha.
- The router was rebuilt inside `build()`, i.e. a new `GoRouter` every frame.

## 3. New: AI that actually does something

Old "AI Studio" was three local `image` package filters (cartoon/sketch/pixel)
plus a text idea generator that needed a key nobody had. The new pipeline is:

```
prompt + style  →  image model  →  cutout  →  trim  →  die-cut border  →  512×512 PNG
```

- **Generation** goes through OpenRouter's `POST /images` (returns
  `data[0].b64_json`) or OpenAI's `POST /images/generations`. Model presets in
  `lib/core/config/ai_settings.dart` record which parameters each endpoint
  actually accepts — sending `background: transparent` to a model that doesn't
  support it is a 400, so it isn't sent.
- Default is **`openai/gpt-image-1-mini`** on OpenRouter, which returns a real
  alpha channel. Nano Banana models are cheaper but opaque, so they go through
  the local cutout.
- **Magic cutout** (`lib/core/utils/image_ops.dart`) is a flood fill inward from
  the border with a feathered edge. No key, no network. It bails out and says so
  when the border is too busy to be a background.
- **Die-cut border** is a chamfer 3-4 distance transform on the alpha channel —
  the classic white sticker outline, applied to the *combined* silhouette at
  save time.
- Everything heavy runs in `Isolate.run`.

`remove.bg` is now optional rather than a hard requirement; if the key is
present it's tried first and falls back locally on failure.

## 4. What to check by hand

| Area | What to look for |
|---|---|
| Release build | Installs, launches, AI network calls succeed |
| Export | Saved sticker has a **transparent** background, no checkerboard |
| Editor | Every layer is individually draggable; drag tracks your finger |
| Die-cut border | Slider in the Border tool, visible after Save |
| WebP export | Android only — iOS silently falls back to PNG (documented, deliberate) |
| Undo/redo | Arrows in the app bar, 40 steps of history |

## 5. Known limits

- **WebP on iOS**: `flutter_image_compress` can't encode WebP there. Sticksy
  falls back to PNG and reports the format it actually produced rather than
  writing a broken file.
- **Key storage** is `SharedPreferences`, not the Keychain/Keystore. Fine for a
  personal key on an unrooted device; if you want it encrypted, add
  `flutter_secure_storage` and swap the two calls in `AiSettingsStore`.
- **`applicationId` is still `com.example.sticksy`.** Changing it means renaming
  the Kotlin package directories and breaks existing installs, so I left it —
  but it must change before a Play Store release.
- **WhatsApp export** is the raw payload (stickers + `contents.json` + tray
  icon). WhatsApp only accepts packs through a companion app implementing its
  content provider, which is a native integration, not something the ZIP can do.
- Minification is off. Re-enabling it needs a real device test.

## 6. Files worth reading

```
lib/core/utils/image_ops.dart              cutout, die-cut outline, square fit
lib/core/config/ai_settings.dart           providers, model presets, persistence
lib/features/ai/data/ai_client.dart        the two API dialects
lib/features/ai/data/ai_repository.dart    the generation pipeline
lib/features/editor/presentation/…         canvas, hit testing, rasterising
```

`test/widget_test.dart` covers the new image ops (cutout actually cuts, outline
grows the canvas, `fitSquare` letterboxes) and the editor controller
(undo/redo, deselect, duplicate, reorder).
