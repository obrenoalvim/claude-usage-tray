# claude-usage-tray

A Windows tray icon that shows your Claude Code 5-hour usage percentage. It updates on its own. You never open Claude Code just to check a number.

Green under 70%. Orange from 70 to 89%. Red at 90% or above. Hover over it to see the exact percentage and when it resets.

🇧🇷 [Leia em português abaixo](#-português)

## Requirements

- Windows
- [Claude Code](https://claude.com/claude-code) installed
- [claude-hud](https://github.com/jarrodwatts/claude-hud) plugin installed and active. Inside Claude Code, run `/plugin marketplace add jarrodwatts/claude-hud`, then `/plugin install claude-hud@claude-hud`.

## Install

Clone this repo, open PowerShell in it, and run:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

The script does four things:

1. Copies `scripts/taskbar-usage.ps1` into `%USERPROFILE%\.claude\scripts\`
2. Turns on `externalUsageWritePath` in the claude-hud config, without touching the rest of your settings
3. Registers the icon to start on login, through the Windows Startup folder
4. Starts the icon immediately

It never touches your credentials. It only reads the snapshot file that claude-hud already writes locally.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

## Let an AI do it for you

Point any Claude Code instance, or another coding agent, at this repo and ask something like:

> "Read the README.md and install.ps1 of this repo, then replicate the install here."

`install.ps1` is idempotent and commented enough for an agent to follow the same steps by hand: copy the script, edit claude-hud's config.json, generate the .vbs launcher, drop it in the Startup folder.

## Limitations

- The icon only shows on the **primary monitor**. That's a Windows limit. No tray icon duplicates onto a second monitor, not even the native ones.
- The icon only updates while a Claude Code session runs, since that session is the only source for rate-limit data. After 15 minutes with no active session, it shows "-" for no data.

---

## 🇧🇷 Português

Um ícone na bandeja do Windows que mostra o percentual de uso da sua janela de 5 horas no Claude Code. Ele atualiza sozinho. Você nunca precisa abrir o Claude Code só pra conferir um número.

Verde abaixo de 70%. Laranja entre 70% e 89%. Vermelho a partir de 90%. Passe o mouse por cima pra ver o percentual exato e quando ele reseta.

### Pré-requisitos

- Windows
- [Claude Code](https://claude.com/claude-code) instalado
- Plugin [claude-hud](https://github.com/jarrodwatts/claude-hud) instalado e ativo. Dentro do Claude Code, roda `/plugin marketplace add jarrodwatts/claude-hud`, depois `/plugin install claude-hud@claude-hud`.

### Instalar

Clona este repo, abre PowerShell nele e roda:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

O script faz quatro coisas:

1. Copia `scripts/taskbar-usage.ps1` pra `%USERPROFILE%\.claude\scripts\`
2. Liga `externalUsageWritePath` no config do claude-hud, sem mexer no resto das suas configurações
3. Registra o ícone pra abrir no login, pela pasta Startup do Windows
4. Sobe o ícone na hora

Ele não mexe em nenhuma credencial. Só lê o arquivo de snapshot que o claude-hud já escreve localmente.

### Desinstalar

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

### Deixa uma IA fazer por você

Aponta qualquer instância de Claude Code, ou outro agente coding, pra este repo e pede algo como:

> "Lê o README.md e o install.ps1 desse repo e replica a instalação aqui."

O `install.ps1` é idempotente e comentado o bastante pra um agente seguir os mesmos passos na mão: copiar o script, editar o config.json do claude-hud, gerar o launcher .vbs, colocar na pasta Startup.

### Limitações

- O ícone só aparece no **monitor principal**. É limitação do Windows. Nenhum ícone de bandeja duplica num segundo monitor, nem os nativos.
- O ícone só atualiza enquanto uma sessão do Claude Code roda, já que essa sessão é a única fonte do dado de rate-limit. Depois de 15 minutos sem sessão ativa, ele mostra "-" por falta de dado.
