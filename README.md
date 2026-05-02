# WhisperDictateMac

Um app macOS simples para ditado local usando Whisper.

O foco inicial é propositalmente estreito:

```txt
Hotkey global -> grava audio -> MLX Whisper local -> cola o texto no app ativo
```

Nada de backend, login, billing, sync, Sparkle ou formatação posterior por LLM. Isso é a versão opensource pequena e hackável, não uma mala de viagem com roda quebrada.

## Requisitos

- macOS 14+
- Xcode 16+
- XcodeGen
- Apple Silicon
- `mlx-whisper` instalado localmente
- `ffmpeg`

Exemplo com Homebrew:

```bash
brew install ffmpeg
python3 -m pip install --user mlx-whisper
```

O modelo padrão é `mlx-community/whisper-large-v3-turbo`. O primeiro uso baixa o modelo via Hugging Face, então a primeira transcrição pode demorar. Depois disso fica local.

## Rodando

```bash
cd /Volumes/SSD1TB/Projetos/WhisperDictateMac
xcodegen generate
xcodebuild build -project WhisperDictateMac.xcodeproj -scheme WhisperDictateMac -destination 'platform=macOS' -quiet
```

Abra o app pelo Xcode ou pelo build gerado.

## Testes

```bash
xcodebuild test -project WhisperDictateMac.xcodeproj -scheme WhisperDictateMac -destination 'platform=macOS'
```

## Configuração

No app, ajuste:

- caminho do executável `mlx_whisper`;
- modelo MLX, por exemplo `mlx-community/whisper-large-v3-turbo`;
- idioma, se quiser fixar `pt`, `en`, etc.

O hotkey padrão é `Control + Shift + D`.

## Licença

MIT. Use, mexa, quebre, conserte e mande PR se ficar bom.

## Próximos passos óbvios

- seletor visual de microfone;
- histórico local;
- VAD para cortar silêncio;
- hotkey configurável;
- empacotar modelo opcional;
- trocar CLI Python por integração direta quando existir um caminho Swift bom;
- formatter local opcional, só depois que o STT estiver redondo.
