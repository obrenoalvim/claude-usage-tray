$ErrorActionPreference = "SilentlyContinue"

$claudeConfigDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".claude" }
$scriptsDir = Join-Path $claudeConfigDir "scripts"

# stop the running tray process
Get-Process powershell -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)").CommandLine
        if ($cmdLine -like "*taskbar-usage.ps1*") { Stop-Process -Id $_.Id -Force }
    } catch {}
}

# remove autostart entry
$startupDir = [Environment]::GetFolderPath('Startup')
Remove-Item (Join-Path $startupDir "taskbar-usage-launch.vbs") -Force

# remove installed scripts
Remove-Item (Join-Path $scriptsDir "taskbar-usage.ps1") -Force
Remove-Item (Join-Path $scriptsDir "taskbar-usage-launch.vbs") -Force

Write-Host "Desinstalado. O claude-hud continua com externalUsageWritePath configurado (inofensivo);"
Write-Host "pra tirar, edita $claudeConfigDir\plugins\claude-hud\config.json e remove essa chave."
