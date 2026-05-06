# DictateOSS

Local-first dictation for macOS, powered by MLX Whisper.

```txt
global hotkey -> record audio -> transcribe locally with MLX Whisper -> paste text into the active app
```

DictateOSS is a native macOS app for people who want fast dictation without sending their voice to a server. It keeps transcription, history, replacement rules, and personal dictionary data on your Mac.

## Why This Exists

Most dictation tools either phone home, hide the model behind a subscription, or both. DictateOSS takes the boringly correct route:

| Thing | DictateOSS |
| --- | --- |
| Transcription | Local MLX Whisper |
| Account | None |
| Backend | None |
| Subscription | None |
| Proprietary telemetry | None |
| Data storage | Local SwiftData |

## Features

- Global hotkey dictation from any macOS app.
- Local transcription through `mlx_whisper`.
- Automatic text insertion into the currently focused app.
- Local transcription history.
- Personal dictionary for domain-specific words and names.
- Replacement rules for fixing repeated transcription mistakes.
- Configurable transcription language: auto, Portuguese, English, Spanish, and French.
- Formatting controls for cleaner pasted text.
- Recording overlay, audio feedback, and menu bar integration.
- Microphone and Accessibility permission onboarding.
- Launch at login support.

## Requirements

- macOS 14 or newer.
- Apple Silicon Mac.
- Xcode 16 or newer.
- XcodeGen.
- Python 3.
- `mlx-whisper`.

Install the command-line dependencies:

```bash
brew install xcodegen
python3 -m pip install --user mlx-whisper
```

Make sure `mlx_whisper` is reachable from your shell:

```bash
which mlx_whisper
```

If it is not on your `PATH`, set the executable path inside the app settings after launch. The default fallback is:

```txt
~/.local/bin/mlx_whisper
```

## Models

The default model is:

```txt
mlx-community/whisper-large-v3-turbo
```

The app also includes presets for:

| Model | Best For | Approx. Size |
| --- | --- | --- |
| `mlx-community/whisper-large-v3-turbo` | Daily use | 1.61 GB |
| `mlx-community/whisper-large-v3-mlx` | Higher accuracy | ~3 GB |
| `mlx-community/whisper-small-mlx` | Lighter transcription | ~1 GB |
| `mlx-community/whisper-tiny` | Setup testing | 74 MB |

Models are downloaded by MLX/Hugging Face on first use unless already cached.

## Build

Generate the Xcode project:

```bash
xcodegen generate
```

Build from the command line:

```bash
xcodebuild build \
  -project DictateOSS.xcodeproj \
  -scheme DictateOSS \
  -destination 'platform=macOS'
```

Run tests:

```bash
xcodebuild test \
  -project DictateOSS.xcodeproj \
  -scheme DictateOSS \
  -destination 'platform=macOS'
```

Or open the project in Xcode:

```bash
open DictateOSS.xcodeproj
```

## Permissions

DictateOSS needs two macOS permissions:

| Permission | Why |
| --- | --- |
| Microphone | Records your voice for transcription. |
| Accessibility | Pastes the transcription into the active app and manages global interaction. |

If dictation records audio but does not paste text, check Accessibility first. macOS is usually the culprit, because of course it is.

## Privacy

DictateOSS is designed to work without an account, server, subscription, or proprietary telemetry.

Your audio is recorded locally, passed to `mlx_whisper`, converted into text, and then deleted as part of the transcription flow. Transcription records, dictionary entries, and replacement rules stay in local app storage.

## Current Status

This is an early open-source macOS app. The core dictation loop works, local history works, and the settings surface is usable. Expect rough edges around packaging, signing, and model setup.

## License

MIT. See [LICENSE](LICENSE).
