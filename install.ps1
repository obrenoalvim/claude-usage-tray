$ErrorActionPreference = "Stop"

$claudeConfigDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".claude" }
$repoDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Claude config dir: $claudeConfigDir"

# 1. check claude-hud plugin is installed
$hudPluginDir = Join-Path $claudeConfigDir "plugins\cache\claude-hud"
if (-not (Test-Path $hudPluginDir)) {
    Write-Warning "Plugin claude-hud nao encontrado em $hudPluginDir"
    Write-Warning "Instala primeiro: dentro do Claude Code, roda '/plugin marketplace add jarrodwatts/claude-hud' e '/plugin install claude-hud@claude-hud'"
    Write-Warning "Continuando a instalacao mesmo assim - o icone so vai mostrar dado depois que o plugin estiver ativo."
}

# 2. copy the tray script
$scriptsDir = Join-Path $claudeConfigDir "scripts"
New-Item -ItemType Directory -Force -Path $scriptsDir | Out-Null
$trayScriptDest = Join-Path $scriptsDir "taskbar-usage.ps1"
Copy-Item (Join-Path $repoDir "scripts\taskbar-usage.ps1") $trayScriptDest -Force
Write-Host "Script copiado para $trayScriptDest"

# 3. enable claude-hud external usage snapshot (merge, don't clobber existing config)
$hudConfigDir = Join-Path $claudeConfigDir "plugins\claude-hud"
New-Item -ItemType Directory -Force -Path $hudConfigDir | Out-Null
$hudConfigPath = Join-Path $hudConfigDir "config.json"
$cacheDir = Join-Path $claudeConfigDir "cache"
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
$snapshotPath = (Join-Path $cacheDir "usage-snapshot.json") -replace '\\', '/'

$config = if (Test-Path $hudConfigPath) {
    Get-Content $hudConfigPath -Raw | ConvertFrom-Json
} else {
    [PSCustomObject]@{}
}
if (-not $config.display) {
    $config | Add-Member -MemberType NoteProperty -Name display -Value ([PSCustomObject]@{})
}
if ($config.display.PSObject.Properties.Name -contains "externalUsageWritePath") {
    $config.display.externalUsageWritePath = $snapshotPath
} else {
    $config.display | Add-Member -MemberType NoteProperty -Name externalUsageWritePath -Value $snapshotPath
}
$config | ConvertTo-Json -Depth 10 | Set-Content $hudConfigPath
Write-Host "claude-hud configurado para escrever snapshot em $snapshotPath"

# 4. generate the hidden launcher (.vbs) with the real absolute path baked in
$vbsPath = Join-Path $scriptsDir "taskbar-usage-launch.vbs"
$vbsContent = @"
Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$trayScriptDest""", 0, False
"@
Set-Content -Path $vbsPath -Value $vbsContent -Encoding ASCII
Write-Host "Launcher gerado em $vbsPath"

# 5. register autostart
$startupDir = [Environment]::GetFolderPath('Startup')
Copy-Item $vbsPath (Join-Path $startupDir "taskbar-usage-launch.vbs") -Force
Write-Host "Autostart registrado em $startupDir"

# 6. (re)start it now
Get-Process powershell -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -eq "" -and $_.Id -ne $PID -and $_.Path -like "*powershell.exe" } |
    ForEach-Object {
        try {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)").CommandLine
            if ($cmdLine -like "*taskbar-usage.ps1*") { Stop-Process -Id $_.Id -Force }
        } catch {}
    }
Start-Sleep -Milliseconds 300
wscript $vbsPath

Write-Host ""
Write-Host "Pronto. Icone deve aparecer na bandeja (perto do relogio) em alguns segundos."
Write-Host "Pra desinstalar: roda uninstall.ps1"
