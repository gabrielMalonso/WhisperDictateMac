# WhisperDictateMac

Aplicativo macOS de ditado local usando MLX Whisper.

```txt
Hotkey global -> grava audio -> MLX Whisper local -> LLM local de formatação -> cola o texto no app ativo
```

Esta branch usa o app original como base visual e de produto, mas remove servicos comerciais e dependencias proprietarias. A transcricao roda localmente.

## Requisitos

- macOS 14+
- Xcode 16+
- XcodeGen
- Apple Silicon
- `mlx_whisper` instalado localmente
- Ollama instalado localmente para formatação com LLM

Exemplo:

```bash
python3 -m pip install --user mlx-whisper
```

O modelo padrao e `mlx-community/whisper-large-v3-turbo`. No primeiro uso, o MLX pode baixar o modelo.

Para a camada de formatação local, instale o Ollama e baixe o modelo padrão:

```bash
brew install ollama
ollama serve
ollama pull qwen2.5:3b
```

O app fala apenas com endpoints locais (`localhost`, `127.0.0.1` ou `::1`). Se o Ollama estiver desligado ou o modelo não estiver disponível, a transcrição continua funcionando e usa o texto bruto do Whisper.

## Build

```bash
xcodegen generate
xcodebuild build -project DictateOSS.xcodeproj -scheme DictateOSS -destination 'platform=macOS'
```

## Estado

- ditado local com MLX Whisper;
- formatação local com LLM via Ollama;
- historico local via SwiftData;
- regras de substituicao e dicionario local;
- permissao de microfone e acessibilidade;
- sem backend, conta, assinatura ou telemetria proprietaria.

## Licenca

MIT.
