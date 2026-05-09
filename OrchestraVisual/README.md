# OrchestraVisual

App macOS (SwiftUI) distribuído como pacote Swift.

## Requisitos

- macOS 14 ou superior
- [Xcode](https://developer.apple.com/xcode/) (recomendado) ou toolchain Swift 5.9+ com suporte a SwiftUI

## Como executar

### Terminal

Na raiz do pacote:

```bash
cd OrchestraVisual
swift run OrchestraVisual
```

Na primeira execução o SwiftPM compila o projeto; depois o app abre em uma janela.

### Xcode

1. Abra o Xcode.
2. **Arquivo → Abrir…** e selecione `Package.swift` nesta pasta.
3. Garanta que o scheme **OrchestraVisual** está selecionado.
4. **Produto → Executar** (⌘R).

### Build release (opcional)

```bash
cd OrchestraVisual
swift build -c release
```

O executável fica em `.build/release/OrchestraVisual`; você pode rodá-lo diretamente a partir daí.
