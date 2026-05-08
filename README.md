# DictateOSS

Local-first dictation for macOS, powered by MLX Whisper, with optional Groq acceleration.

```txt
global hotkey -> record audio -> transcribe locally or with Groq -> paste text into the active app
```

DictateOSS is a native macOS app for people who want fast dictation and a real privacy choice. Local mode keeps transcription, history, replacement rules, and personal dictionary data on your Mac. Groq mode is optional and faster, but sends audio and text to Groq using your own API key.

## Why This Exists

Most dictation tools either phone home, hide the model behind a subscription, or both. DictateOSS takes the boringly correct route:

| Thing | DictateOSS |
| --- | --- |
| Transcription | Local MLX Whisper by default, optional Groq |
| Account | None for Local mode; Groq key if you choose Groq |
| Backend | None |
| Subscription | None |
| Proprietary telemetry | None |
| Data storage | Local SwiftData |

## Features

- Global hotkey dictation from any macOS app.
- Local transcription through `mlx_whisper`.
- Optional Groq transcription and LLM cleanup with your own API key.
- Three AI modes: Local, Groq, and Custom.
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

## AI Modes

| Mode | Transcription | LLM cleanup | Best for |
| --- | --- | --- | --- |
| Local | MLX Whisper | Off by default | Privacy, offline use, no API cost |
| Groq | Groq Whisper | Groq LLM | Speed, low CPU/RAM use, simple setup |
| Custom | Local or Groq | Off, Ollama, or Groq | Mixing privacy and convenience |

Groq settings use these defaults:

| Stage | Default model | Notes |
| --- | --- | --- |
| Speech-to-text | `whisper-large-v3-turbo` | Fast and cheap for daily dictation |
| LLM cleanup | `openai/gpt-oss-20b` | Good default for punctuation, formatting, and light rewriting |

Groq API keys are stored in the macOS Keychain, not in UserDefaults. If Groq fails and local fallback is enabled, DictateOSS tries MLX Whisper before giving up. Sensible behavior; shocking concept.

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

In Local mode, your audio is recorded locally, passed to `mlx_whisper`, converted into text, and then deleted as part of the transcription flow. Transcription records, dictionary entries, and replacement rules stay in local app storage.

In Groq mode, the recorded audio is sent to Groq for transcription, and the resulting text may be sent to Groq again for LLM cleanup. The temporary audio file is still deleted locally after the flow completes. Use Local mode when privacy matters more than speed.

## Current Status

This is an early open-source macOS app. The core dictation loop works, local history works, and the settings surface is usable. Expect rough edges around packaging, signing, and model setup.

## License

MIT. See [LICENSE](LICENSE).
