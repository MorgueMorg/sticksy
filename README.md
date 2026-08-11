# Sticksy

Turn an idea into a sticker pack. Describe what you want, let a model draw it,
cut it out, add the classic white die-cut border, and export for WhatsApp,
Telegram or as a plain ZIP.

## Getting started

```bash
flutter pub get
flutter run
```

Then open **Settings → AI** and paste an API key:

- **OpenRouter** (recommended) — https://openrouter.ai/keys
- **OpenAI** — https://platform.openai.com/api-keys

The key is stored on the device only and is never sent anywhere except the
provider you picked. Tap **Test connection** to verify it before generating.

There is no `.env` file and no key baked into the build.

### Recommended model

`openai/gpt-image-1-mini` on OpenRouter. It returns PNGs with a real alpha
channel, which is exactly what a sticker needs. Cheaper models (Nano Banana,
FLUX) work too — Sticksy cuts their background out on device.

## What it does

- **AI Studio** — prompt + one of eight art styles → a finished 512×512 sticker
- **Magic cutout** — removes flat backgrounds on device, no key or network
- **Die-cut border** — adjustable white outline traced around the whole sticker
- **Layer editor** — images, text, emoji, shapes, freehand drawing, 40 steps of
  undo
- **Packs** — reorderable, searchable, with covers
- **Export** — WhatsApp, Telegram or ZIP; always 512×512 with transparency

## Release builds

For a signed release, create `android/key.properties`:

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

Without it the release build falls back to the debug key so it still installs.

```bash
flutter build apk --release
flutter build appbundle --release
```

Code shrinking is deliberately disabled — see `HANDOFF.md`.

## Layout

```
lib/
  core/
    config/      theme, colours, router, AI settings
    utils/       image ops (cutout, outline), formatting, Result
    widgets/     shared UI kit
  features/
    ai/          clients, generation pipeline, AI Studio
    editor/      canvas, layers, rasterising
    packs/       pack list, pack detail, export
    settings/    AI connection, storage
    onboarding/
  shared/data/   drift database, file storage
```

## Tests

```bash
flutter test
```
