# DictateOSS

Local-first dictation for macOS, powered by MLX Whisper, with optional Groq acceleration.

```txt
global hotkey -> record audio -> transcribe locally or with Groq -> paste text into the active app
```

DictateOSS is a native macOS app for people who want fast dictation and a real privacy choice. Local mode keeps transcription, history, replacement rules, and personal dictionary data on your Mac. Groq mode is optional and faster, but sends audio and text to Groq using your own API key.

## Latest Main Update

The latest merged PR on `main` is [#5](https://github.com/gabrielMalonso/WhisperDictateMac/pull/5), `feature/ai-provider-selection`: **AI provider selection with Groq and local fallback**.

What changed:

| Area | New behavior |
| --- | --- |
| AI modes | Choose between Groq, Local, or Custom mode. |
| Fast path | Groq is now the default quick setup for transcription and cleanup. |
| Privacy path | Local MLX Whisper still works without an account, server, or API key. |
| Custom routing | Mix local/Groq transcription with off, Ollama, or Groq-powered LLM cleanup. |
| Fallback | Groq can fall back to local MLX Whisper when the API key, network, auth, or rate limit gets in the way. |
| Credentials | Groq API keys are stored in macOS Keychain. |
| Onboarding | New Groq onboarding step and dedicated AI settings sheet. |
| Localization | The app now ships with `Localizable.xcstrings` and an i18n workflow prompt. |

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

| Mode | Transcription provider | LLM cleanup provider | Best for |
| --- | --- | --- | --- |
| Groq | Groq | Groq | Default fast path, low CPU/RAM use, simple setup |
| Local | MLX Whisper | Off by default | Privacy, offline use, no API cost |
| Custom | Local or Groq | Off, Ollama, or Groq | Mixing privacy and convenience |

The app treats Groq as the primary quick provider. Private local models are still available, but their model/tool setup lives in Settings > Tools.

```txt
Groq mode:
record audio -> Groq speech-to-text -> Groq chat cleanup -> paste text

Local mode:
record audio -> MLX Whisper -> paste text

Custom mode:
record audio -> chosen transcription provider -> optional chosen LLM cleanup -> paste text
```

When Groq is selected as the provider, these are the default models:

| Stage | Default model | Notes |
| --- | --- | --- |
| Speech-to-text | `whisper-large-v3-turbo` | Fast and cheap for daily dictation |
| LLM cleanup | `openai/gpt-oss-20b` | Good default for punctuation, formatting, and light rewriting |

Groq model pricing and throughput change over time, because pricing pages are living things with caffeine. Snapshot checked on 2026-05-08:

| Model | Used for | Price | Published speed | Base Developer limits |
| --- | --- | --- | --- | --- |
| [`whisper-large-v3-turbo`](https://console.groq.com/docs/model/whisper-large-v3-turbo) | Speech-to-text default | $0.04 / audio hour | 216x speed factor | 20 RPM, 2K RPD, 7.2K ASH, 28.8K ASD |
| [`whisper-large-v3`](https://console.groq.com/docs/model/whisper-large-v3) | Higher-accuracy speech-to-text option | $0.111 / audio hour | 189x speed factor | 20 RPM, 2K RPD, 7.2K ASH, 28.8K ASD |
| [`openai/gpt-oss-20b`](https://console.groq.com/docs/model/openai/gpt-oss-20b) | LLM cleanup default | $0.075 input / $0.0375 cached input / $0.30 output per 1M tokens | ~1000 TPS | 30 RPM, 1K RPD, 8K TPM, 200K TPD |
| [`openai/gpt-oss-120b`](https://console.groq.com/docs/model/openai/gpt-oss-120b) | Higher-capability LLM cleanup option | $0.15 input / $0.075 cached input / $0.60 output per 1M tokens | ~500 TPS | 30 RPM, 1K RPD, 8K TPM, 200K TPD |
| [`llama-3.1-8b-instant`](https://console.groq.com/docs/model/llama-3.1-8b-instant) | Fast, cheap LLM cleanup option | $0.05 input / $0.08 output per 1M tokens | ~560 TPS | 30 RPM, 14.4K RPD, 6K TPM, 500K TPD |
| [`llama-3.3-70b-versatile`](https://console.groq.com/docs/model/llama-3.3-70b-versatile) | Stronger LLM cleanup option | $0.59 input / $0.79 output per 1M tokens | ~280 TPS | 30 RPM, 1K RPD, 12K TPM, 100K TPD |

Speech models are priced by audio hour, not token count, so Groq publishes a speed factor instead of token-per-second throughput. Check the [Groq pricing](https://groq.com/pricing) and [rate limits](https://console.groq.com/docs/rate-limits) pages before making cost promises to users with a straight face.

Custom mode also supports local LLM cleanup through Ollama. That means you can keep transcription local, use Groq only for speed, or split the difference like a sensible adult.

Groq API keys are stored in the macOS Keychain, not in UserDefaults. If Groq fails and local fallback is enabled, DictateOSS tries MLX Whisper before giving up. Sensible behavior; shocking concept.

## Groq Setup

Groq is optional, but it is now the fastest path through the app.

1. Open DictateOSS.
2. Complete the Groq onboarding step, or skip it and open Settings > AI later.
3. Paste your Groq API key.
4. Test the connection.
5. Keep local fallback enabled if you want dictation to survive bad network days.

No key? Use Local mode. That is the whole point of the app.

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

DictateOSS also ships with App Sandbox disabled. That is intentional, not a spooky checkbox accident. Global dictation needs system-level interaction: listening for the hotkey, reading the focused text context, temporarily swapping the clipboard, simulating `Command+V`, and running the user-installed `mlx_whisper` binary from your local machine.

If dictation records audio but does not paste text, check Accessibility first. macOS is usually the culprit, because of course it is.

## Privacy

DictateOSS is designed to work without an account, server, subscription, or proprietary telemetry.

In Local mode, your audio is recorded locally, passed to `mlx_whisper`, converted into text, and then deleted as part of the transcription flow. Transcription records, dictionary entries, and replacement rules stay in local app storage.

In Groq mode, the recorded audio is sent to Groq for transcription, and the resulting text may be sent to Groq again for LLM cleanup. The temporary audio file is still deleted locally after the flow completes. Use Local mode when privacy matters more than speed.

Local storage means local, not magically encrypted. Your transcription history is kept in the app's SwiftData store on your Mac. Your Groq API key is the exception: it goes into macOS Keychain.

## Current Status

This is an early open-source macOS app. The core dictation loop works, Groq and local provider selection are wired in, local history works, and the settings surface is usable. Expect rough edges around packaging, signing, and model setup.

## License

MIT. See [LICENSE](LICENSE).
