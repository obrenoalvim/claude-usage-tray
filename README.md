# claude-usage-tray

Windows system tray icon (near volume/mic/network) showing your Claude Code
**5-hour window usage %** — updates on its own, no need to open Claude Code
to check.

Green <70%, orange 70-89%, red ≥90%. Hover: shows exact % and reset time.

🇧🇷 [Leia em português abaixo](#-português)

## Requirements

- Windows
- [Claude Code](https://claude.com/claude-code) installed
- [claude-hud](https://github.com/jarrodwatts/claude-hud) plugin installed and active
  (inside Claude Code: `/plugin marketplace add jarrodwatts/claude-hud` then
  `/plugin install claude-hud@claude-hud`)

## Install

Download/clone this repo, open PowerShell in it and run:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

This will:
1. Copy `scripts/taskbar-usage.ps1` to `%USERPROFILE%\.claude\scripts\`
2. Enable `externalUsageWritePath` in the claude-hud config (without touching the rest of your config)
3. Register the icon to auto-start on login (Windows Startup folder)
4. Start the icon right away

Doesn't touch any credentials — only reads the snapshot file that claude-hud
already writes locally.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

## Prefer asking an AI to do it

Instead of running `install.ps1`, you can point any Claude Code instance
(or other coding agent) at this repo and ask something like:

> "read the README.md and install.ps1 of this repo and replicate the install here"

`install.ps1` is idempotent and commented enough for an agent to follow the
same steps manually if it prefers (copy script, edit claude-hud's config.json,
generate the .vbs, place it in the Startup folder).

## Limitations

- Only shows up in the tray of the **primary monitor** — this is a Windows
  limitation (no tray icon duplicates on a secondary monitor, not even native ones).
- Only updates while a Claude Code session is running (it's the only source
  of rate-limit data). After 15min with no active session, the icon shows
  "-" (no data).

---

## 🇧🇷 Português

Ícone na bandeja do Windows (perto de volume/mic/rede) mostrando o **% de uso
da janela de 5h** do seu plano Claude Code — atualiza sozinho, sem precisar
abrir o Claude Code pra ver.

Verde <70%, laranja 70-89%, vermelho ≥90%. Passa o mouse: mostra % exato e
quando reseta.

### Pré-requisitos

- Windows
- [Claude Code](https://claude.com/claude-code) instalado
- Plugin [claude-hud](https://github.com/jarrodwatts/claude-hud) instalado e ativo
  (dentro do Claude Code: `/plugin marketplace add jarrodwatts/claude-hud` depois
  `/plugin install claude-hud@claude-hud`)

### Instalar

Baixa/clona este repo, abre PowerShell nele e roda:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

Isso:
1. Copia `scripts/taskbar-usage.ps1` pra `%USERPROFILE%\.claude\scripts\`
2. Liga `externalUsageWritePath` no config do claude-hud (sem mexer no resto do seu config)
3. Registra o ícone pra abrir sozinho no login (pasta Startup do Windows)
4. Sobe o ícone agora mesmo

Não mexe em nenhuma credencial — só lê o arquivo de snapshot que o claude-hud
já escreve localmente.

### Desinstalar

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

### Se preferir pedir pra uma IA fazer

Em vez de rodar o `install.ps1`, dá pra apontar qualquer instância de Claude
Code (ou outro agente coding) pra este repo e pedir algo como:

> "lê o README.md e o install.ps1 desse repo e replica a instalação aqui"

O `install.ps1` é idempotente e comentado o bastante pra um agente seguir os
mesmos passos manualmente se preferir (copiar script, editar config.json do
claude-hud, gerar o .vbs, colocar na pasta Startup).

### Limitações

- Só aparece na bandeja do **monitor principal** — é limitação do Windows
  (nenhum ícone de bandeja duplica em monitor secundário, nem os nativos).
- Só atualiza enquanto alguma sessão do Claude Code estiver rodando (é a
  única fonte do dado de rate-limit). Depois de 15min sem sessão ativa, o
  ícone mostra "-" (sem dado).
