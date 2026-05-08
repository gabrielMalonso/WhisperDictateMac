# Prompt para completar traduções i18n

Use este prompt em outra LLM para completar apenas as traduções em inglês que ainda faltam.

```text
Você vai trabalhar em um projeto macOS SwiftUI chamado DictateOSS.

Arquivo que deve ser editado:
DictateOSS/Localizable.xcstrings

Objetivo:
Adicionar traduções em inglês APENAS para as entradas que ainda não possuem localização "en".

Contexto importante:
- A língua fonte do projeto é pt-BR.
- O arquivo já contém muitas traduções em inglês reaproveitadas do app original.
- NÃO retraduza entradas que já têm "en".
- NÃO remova "pt-BR".
- NÃO remova comentários.
- NÃO reordene o arquivo se não for necessário.
- NÃO mude nenhuma chave dentro de "strings".
- Só adicione ou complete blocos "en" ausentes.

Como identificar o que precisa tradução:
Dentro de `Localizable.xcstrings`, procure entradas neste formato:

```json
"Chave em português" : {
  "localizations" : {
    "pt-BR" : {
      "stringUnit" : {
        "state" : "new",
        "value" : "Texto em português"
      }
    }
  }
}
```

Você deve adicionar `"en"` como irmã de `"pt-BR"`:

```json
"Chave em português" : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "English translation here"
      }
    },
    "pt-BR" : {
      "stringUnit" : {
        "state" : "new",
        "value" : "Texto em português"
      }
    }
  }
}
```

Se a entrada não tiver `localizations`, crie:

```json
"Texto em português" : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "English translation"
      }
    }
  }
}
```

Regras obrigatórias:
1. Traduza somente entradas sem `localizations.en.stringUnit.value`.
2. Preserve exatamente todos os placeholders: `%@`, `%d`, `%lld`, `%1$@`, `%2$@`, `%3$@`.
3. Nunca traduza nomes técnicos ou marcas: Dictate, DictateOSS, Groq, Ollama, MLX Whisper, Keychain, UserDefaults, GitHub, OpenAI, Kubernetes.
4. Não traduza modelos/identificadores: `gsk_...`, `llama3.1`, `mlx_whisper`, `mlx-community/whisper-large-v3-turbo`, `whisper-large-v3-turbo`, `openai/gpt-oss-20b`.
5. Mantenha atalhos e símbolos intactos: `⌘`, `⌃`, `⇧`, `⌥`, `×`, `%`, `·`.
6. Traduza para inglês natural de app macOS, curto e claro.
7. Botões devem ser curtos: Save, Delete, Cancel, Continue, Test, Download, Install.
8. Mensagens de erro devem ser úteis e diretas.
9. Use "Settings" para "Ajustes".
10. Use "System Settings" para "Ajustes do Sistema".
11. Use "Hotkey" para "atalho/hotkey".
12. Use "Dictation" para "ditado/ditação" quando for recurso.
13. Use "Transcription" para "transcrição".
14. Use "Recording" para "gravação".
15. Use "Local fallback" para "Fallback local".
16. Use "AI mode" para "Modo de IA".
17. Use "Groq API key" para "Chave da Groq".

Glossário obrigatório:
- Avançado -> Advanced
- Baixa no primeiro uso -> Downloads on first use
- Baixando -> Downloading
- Baixando modelo -> Downloading model
- Baixar modelo -> Download model
- Caminho do mlx_whisper -> mlx_whisper path
- Chave apagada. -> Key deleted.
- Chave da Groq -> Groq API key
- Chave salva. -> Key saved.
- Chave salva no Keychain. -> Key saved in Keychain.
- Configurar IA -> Configure AI
- Conta Groq -> Groq account
- Desligado -> Off
- Em breve -> Coming soon
- Excluindo -> Deleting
- Excluir do cache -> Delete from cache
- Ferramentas -> Tools
- Modo de IA -> AI mode
- Privado -> Private
- Rápido -> Fast
- Testar conexão -> Test connection

Traduções sugeridas para termos recorrentes:
- "Tudo roda neste Mac." -> "Everything runs on this Mac."
- "Escolha quem transforma áudio em texto." -> "Choose what turns audio into text."
- "Pontua, reescreve e traduz quando solicitado." -> "Adds punctuation, rewrites, and translates when requested."
- "Se a Groq falhar, tenta MLX Whisper local antes de desistir." -> "If Groq fails, try local MLX Whisper before giving up."
- "Ollama local não respondeu. Abra o Ollama ou escolha outro modo." -> "Local Ollama did not respond. Open Ollama or choose another mode."
- "A Groq retornou uma resposta inválida." -> "Groq returned an invalid response."
- "A Groq retornou texto vazio." -> "Groq returned empty text."
- "A transcrição ficou vazia." -> "The transcription was empty."

Atenção especial a placeholders:
Exemplo com `%@`:

```json
"Modelo remoto inválido: %@" : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Invalid remote model: %@"
      }
    }
  }
}
```

Exemplo com múltiplos placeholders:

```json
"MLX Whisper terminou, mas não gerou transcrição. Esperado: %@. Gerados: %@." : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "MLX Whisper finished, but did not generate a transcription. Expected: %@. Generated: %@."
      }
    }
  }
}
```

Antes de finalizar:
1. Garanta que o JSON continua válido.
2. Garanta que nenhuma chave foi alterada.
3. Garanta que nenhuma tradução existente em "en" foi substituída.
4. Garanta que todos os placeholders continuam exatamente iguais.
5. Ao final, informe quantas entradas "en" foram adicionadas.

Validação obrigatória:
Rode:

```bash
python3 -m json.tool DictateOSS/Localizable.xcstrings >/tmp/localizable.check
xcodebuild -project DictateOSS.xcodeproj -exportLocalizations -localizationPath /tmp/dictateoss-i18n-export-en -exportLanguage en
```

Resultado esperado:
- JSON válido.
- `xcodebuild` com exit code 0.
- Nenhum erro de `Localizable.xcstrings`.

Não faça mais nada além de completar as traduções em inglês ausentes nesse arquivo.
```
