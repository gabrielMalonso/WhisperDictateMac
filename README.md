# WhisperDictateMac

Aplicativo macOS de ditado local usando MLX Whisper.

```txt
Hotkey global -> grava audio -> MLX Whisper local -> cola o texto no app ativo
```

Esta branch usa o app original como base visual e de produto, mas remove servicos comerciais e dependencias proprietarias. A transcricao roda localmente.

## Requisitos

- macOS 14+
- Xcode 16+
- XcodeGen
- Apple Silicon
- `mlx_whisper` instalado localmente

Exemplo:

```bash
python3 -m pip install --user mlx-whisper
```

O modelo padrao e `mlx-community/whisper-large-v3-turbo`. No primeiro uso, o MLX pode baixar o modelo.

## Build

```bash
xcodegen generate
xcodebuild build -project DictateApp.xcodeproj -scheme DictateApp -destination 'platform=macOS'
```

## Estado

- ditado local com MLX Whisper;
- historico local via SwiftData;
- regras de substituicao e dicionario local;
- permissao de microfone e acessibilidade;
- sem backend, conta, assinatura ou telemetria proprietaria.

## Licenca

MIT.
