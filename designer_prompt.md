# Designer Prompt & Style Guide: Jacklava Garage

Este guia detalha o sistema de design e a lógica técnica da interface da **Garagem**. Use estas informações para manter a consistência visual e funcional ao criar novos scripts.

---

## 🛠️ Tecnologias Utilizadas (Tech Stack)

- **Estrutura**: HTML5 (Semântico).
- **Estilização**: CSS3 Vanilla (Dark Premium Aesthetics).
- **Lógica**: JavaScript Vanilla (ES6+).
- **Comunicação**: `fetch` API para POST callbacks.
- **Ícones**: [FontAwesome 6.4.0](https://fontawesome.com/).
- **Tipografia**: Google Fonts (Inter e Roboto).

---

## 🎨 Sistema de Design (Black Piano & Cyan Neon)

### Paleta de Cores
A interface foca em um contraste futurista e elegante.

| Variável CSS | Hex | Uso |
| :--- | :--- | :--- |
| `--bg` | `#0b0b0b` | Background principal. |
| `--secondary` | `#111111` | Sidebar e Header. |
| `--accent` | `#1a1a1a` | Cards de veículos. |
| `--highlight` | `#00e5ff` | Cor de destaque (Cyan Neon), ícones e títulos. |
| `--border` | `#222222` | Divisores sutis. |

---

## ⚙️ Fluxo de Callbacks (NUI -> Lua)

A interface se comunica com o cliente através dos seguintes endpoints de POST:

1. **`close`**: Fechar a UI.
2. **`spawnVehicle`**: Retirar veículo ou pagar pátio.
3. **`transferVehicle`**: Transferir dono.
4. **`renameVehicle`**: Mudar o nome do veículo.
5. **`copyKeys`**: Criar cópia da chave (Item).

---

## 🚀 AI Master Prompt para Design

> "Desenvolva uma interface NUI para FiveM com estética Black Piano. Fundo ultra-escuro (#0b0b0b), cantos arredondados de 14px e detalhes em ciano neon (#00e5ff). Grid de itens e sidebar para detalhes. Use barras de progresso finas."
