$claudeConfigDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".claude" }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# GetHicon() hands back a raw HICON that Icon.FromHandle() does not own, so
# .Dispose() never frees it. Without an explicit DestroyIcon, every 5s tick
# leaks a GDI handle until the process hits Windows' 10000-per-process cap
# and the tray icon freezes on whatever was last drawn.
Add-Type -Namespace ClaudeUsageTray -Name NativeMethods -MemberDefinition '
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool DestroyIcon(System.IntPtr hIcon);
'

# Explorer restarts (crash, update, theme change) silently drop every tray
# icon; Windows broadcasts "TaskbarCreated" when that happens, and an app
# that doesn't listen for it stays invisible forever until relaunched.
Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @"
using System;
using System.Windows.Forms;
using System.Runtime.InteropServices;

namespace ClaudeUsageTray {
    public class TaskbarWatcher : NativeWindow, IDisposable {
        [DllImport("user32.dll")]
        private static extern int RegisterWindowMessage(string lpString);

        public static readonly int WM_TASKBARCREATED = RegisterWindowMessage("TaskbarCreated");

        public event EventHandler TaskbarCreated;

        public TaskbarWatcher() {
            CreateHandle(new CreateParams());
        }

        protected override void WndProc(ref Message m) {
            if (m.Msg == WM_TASKBARCREATED && TaskbarCreated != null) {
                TaskbarCreated(this, EventArgs.Empty);
            }
            base.WndProc(ref m);
        }

        public void Dispose() {
            DestroyHandle();
        }
    }
}
"@

$script:snapshotPath = Join-Path $claudeConfigDir "cache\usage-snapshot.json"
$script:freshnessMs  = 15 * 60 * 1000   # ignore snapshot older than 15 min

# last good reading, so a stale/missing snapshot shows an old number instead of a bare dash
$script:lastKnownPath = Join-Path $claudeConfigDir "scripts\.tray-last-known.json"
$script:lastKnown = $null
if (Test-Path $script:lastKnownPath) {
    try { $script:lastKnown = Get-Content $script:lastKnownPath -Raw | ConvertFrom-Json } catch { $script:lastKnown = $null }
}

# language preference persists next to the script so it survives reinstall/restart
$script:langPath = Join-Path $claudeConfigDir "scripts\.tray-lang"
$script:lang = "pt"
if (Test-Path $script:langPath) {
    $saved = (Get-Content $script:langPath -Raw -ErrorAction SilentlyContinue)
    if ($saved) { $saved = $saved.Trim() }
    if ($saved -eq "en" -or $saved -eq "pt") { $script:lang = $saved }
}

$script:strings = @{
    pt = @{
        NoData    = "Claude - sem dado"
        Error     = "Claude - erro lendo dado"
        FiveHour  = "Claude - 5h"
        ResetIn   = " (reseta em {0}h {1}min)"
        Week      = "Sem"
        WeekReset = " ({0}h{1}m)"
        RunsOutIn = " esgota em {0}"
        Stale     = " (dado antigo, {0})"
        Exit      = "Sair"
    }
    en = @{
        NoData    = "Claude - no data"
        Error     = "Claude - error reading data"
        FiveHour  = "Claude - 5h"
        ResetIn   = " (resets in {0}h {1}min)"
        Week      = "Week"
        WeekReset = " ({0}h{1}m)"
        RunsOutIn = " runs out in {0}"
        Stale     = " (stale data, {0})"
        Exit      = "Exit"
    }
}

function T {
    param([string]$Key)
    return $script:strings[$script:lang][$Key]
}

function New-PercentIcon {
    param(
        [string]$Text,
        [System.Drawing.Color]$BgColor
    )
    $bmp = New-Object System.Drawing.Bitmap(32, 32)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)
    $brush = New-Object System.Drawing.SolidBrush($BgColor)
    $g.FillEllipse($brush, 0, 0, 32, 32)

    $fontSize = if ($Text.Length -gt 2) { 10 } else { 13 }
    $font = New-Object System.Drawing.Font("Segoe UI", $fontSize, [System.Drawing.FontStyle]::Bold)
    $textBrush = [System.Drawing.Brushes]::White
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = 'Center'
    $format.LineAlignment = 'Center'
    $rect = New-Object System.Drawing.RectangleF(0, 0, 32, 32)
    $g.DrawString($Text, $font, $textBrush, $rect, $format)
    $g.Dispose()
    $brush.Dispose()
    $font.Dispose()
    $format.Dispose()

    $hicon = $bmp.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($hicon)
    $bmp.Dispose()
    return $icon
}

function Set-TrayIcon {
    param(
        [string]$Text,
        [System.Drawing.Color]$BgColor,
        [string]$TooltipText
    )
    $oldIcon = $script:trayIcon.Icon
    $script:trayIcon.Icon = New-PercentIcon -Text $Text -BgColor $BgColor
    $script:trayIcon.Text = $TooltipText
    if ($oldIcon) {
        $oldHandle = $oldIcon.Handle
        $oldIcon.Dispose()
        [ClaudeUsageTray.NativeMethods]::DestroyIcon($oldHandle) | Out-Null
    }
}

$script:trayIcon = New-Object System.Windows.Forms.NotifyIcon
Set-TrayIcon -Text "?" -BgColor ([System.Drawing.Color]::Gray) -TooltipText (T "FiveHour")
$script:trayIcon.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$script:ptItem = $menu.Items.Add("Português")
$script:enItem = $menu.Items.Add("English")
$script:ptItem.CheckOnClick = $false
$script:enItem.CheckOnClick = $false
$menu.Items.Add("-") | Out-Null
$script:exitItem = $menu.Items.Add((T "Exit"))
$script:exitItem.Add_Click({
    $script:trayIcon.Visible = $false
    $script:timer.Stop()
    [System.Windows.Forms.Application]::Exit()
})
$script:trayIcon.ContextMenuStrip = $menu

$script:taskbarWatcher = New-Object ClaudeUsageTray.TaskbarWatcher
$script:taskbarWatcher.add_TaskbarCreated({
    $script:trayIcon.Visible = $false
    $script:trayIcon.Visible = $true
    Update-Usage
})

function Set-Language {
    param([string]$NewLang)
    $script:lang = $NewLang
    Set-Content -Path $script:langPath -Value $NewLang -NoNewline
    $script:ptItem.Checked = ($NewLang -eq "pt")
    $script:enItem.Checked = ($NewLang -eq "en")
    $script:exitItem.Text = T "Exit"
    Update-Usage
}
$script:ptItem.Add_Click({ Set-Language "pt" })
$script:enItem.Add_Click({ Set-Language "en" })
$script:ptItem.Checked = ($script:lang -eq "pt")
$script:enItem.Checked = ($script:lang -eq "en")

function Get-RiskColor {
    param([int]$Pct)
    if ($Pct -ge 90) { return [System.Drawing.Color]::Crimson }
    if ($Pct -ge 70) { return [System.Drawing.Color]::DarkOrange }
    return [System.Drawing.Color]::SeaGreen
}

# ponytail: taxa de consumo semanal calculada a partir de amostras em memoria
# (perde o historico se a bandeja reiniciar - ~15-20min pra taxa ficar confiavel
# de novo). Persistir em arquivo se isso incomodar na pratica.
if (-not $script:weeklyHistory) { $script:weeklyHistory = [System.Collections.Generic.List[psobject]]::new() }
$script:weeklyLookbackMs = 60 * 60 * 1000   # janela de 60min pra calcular a taxa
$script:weeklyMinSpanMs  = 5 * 60 * 1000    # so confia na taxa com >=5min de dado

function Get-WeeklyExhaustWarning {
    param([int]$Pct, [long]$NowMs, [string]$ResetsAtRaw)

    $script:weeklyHistory.Add([PSCustomObject]@{ t = $NowMs; pct = $Pct })
    while ($script:weeklyHistory.Count -gt 0 -and ($NowMs - $script:weeklyHistory[0].t) -gt $script:weeklyLookbackMs) {
        $script:weeklyHistory.RemoveAt(0)
    }

    if ($script:weeklyHistory.Count -lt 2 -or -not $ResetsAtRaw) { return $null }

    $oldest = $script:weeklyHistory[0]
    $span = $NowMs - $oldest.t
    if ($span -lt $script:weeklyMinSpanMs) { return $null }

    $rate = ($Pct - $oldest.pct) / $span   # % por ms
    if ($rate -le 0 -or $Pct -ge 100) { return $null }

    $msToExhaust = (100 - $Pct) / $rate
    $exhaustAtMs = $NowMs + $msToExhaust
    $resetsAtMs = [DateTimeOffset]::Parse($ResetsAtRaw).ToUnixTimeMilliseconds()
    if ($exhaustAtMs -ge $resetsAtMs) { return $null }

    $hrs = [int]($msToExhaust / 3600000)
    $mins = [int](($msToExhaust % 3600000) / 60000)
    return "${hrs}h${mins}m"
}

function Save-LastKnown {
    param([int]$FiveHourPct, $WeeklyPct)
    if ($script:lastKnown -and $script:lastKnown.five_hour -eq $FiveHourPct -and $script:lastKnown.seven_day -eq $WeeklyPct) { return }
    $script:lastKnown = [PSCustomObject]@{
        five_hour = $FiveHourPct
        seven_day = $WeeklyPct
        at        = (Get-Date).ToString("HH:mm")
    }
    $script:lastKnown | ConvertTo-Json | Set-Content -Path $script:lastKnownPath
}

function Show-NoData {
    if ($script:lastKnown -and $null -ne $script:lastKnown.five_hour) {
        $weeklyPart = ""
        if ($null -ne $script:lastKnown.seven_day) {
            $weeklyPart = " | $(T 'Week'): $($script:lastKnown.seven_day)%"
        }
        $tooltip = "$(T 'FiveHour'): $($script:lastKnown.five_hour)%$weeklyPart" + ((T "Stale") -f $script:lastKnown.at)
        if ($tooltip.Length -gt 63) { $tooltip = $tooltip.Substring(0, 60) + "..." }
        Set-TrayIcon -Text "$($script:lastKnown.five_hour)" -BgColor ([System.Drawing.Color]::Gray) -TooltipText $tooltip
    } else {
        Set-TrayIcon -Text "-" -BgColor ([System.Drawing.Color]::Gray) -TooltipText (T "NoData")
    }
}

function Update-Usage {
    if (-not (Test-Path $script:snapshotPath)) {
        Show-NoData
        return
    }
    try {
        $json = Get-Content $script:snapshotPath -Raw | ConvertFrom-Json
        $updatedAt = [DateTimeOffset]::Parse($json.updated_at).ToUnixTimeMilliseconds()
        $nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $pct = $json.five_hour.used_percentage

        if (($nowMs - $updatedAt) -gt $script:freshnessMs -or $null -eq $pct) {
            Show-NoData
            return
        }

        $pct = [int]$pct
        $color = Get-RiskColor $pct

        $resetInfo = ""
        if ($json.five_hour.resets_at) {
            $resetsAt = [DateTimeOffset]::Parse($json.five_hour.resets_at)
            $remaining = $resetsAt.ToUniversalTime() - [DateTimeOffset]::UtcNow
            if ($remaining.TotalMinutes -gt 0) {
                $resetInfo = (T "ResetIn") -f [int]$remaining.TotalHours, $remaining.Minutes
            }
        }

        $tooltip = "$(T 'FiveHour'): $pct%$resetInfo"

        $weeklyPct = $json.seven_day.used_percentage
        if ($null -ne $weeklyPct) {
            $weeklyPct = [int]$weeklyPct
            $color = if ($color -eq [System.Drawing.Color]::Crimson) { $color } else { Get-RiskColor $weeklyPct }

            $weeklyResetInfo = ""
            if ($json.seven_day.resets_at) {
                $weeklyResetsAt = [DateTimeOffset]::Parse($json.seven_day.resets_at)
                $weeklyRemaining = $weeklyResetsAt.ToUniversalTime() - [DateTimeOffset]::UtcNow
                if ($weeklyRemaining.TotalMinutes -gt 0) {
                    $weeklyResetInfo = (T "WeekReset") -f [int]$weeklyRemaining.TotalHours, $weeklyRemaining.Minutes
                }
            }

            $exhaustWarning = Get-WeeklyExhaustWarning -Pct $weeklyPct -NowMs $nowMs -ResetsAtRaw $json.seven_day.resets_at
            if ($exhaustWarning) {
                $color = [System.Drawing.Color]::Crimson
                $tooltip += " | $(T 'Week'): $weeklyPct%$weeklyResetInfo" + ((T "RunsOutIn") -f $exhaustWarning)
            } else {
                $tooltip += " | $(T 'Week'): $weeklyPct%$weeklyResetInfo"
            }
        }

        # NotifyIcon.Text estoura excecao acima de ~63 chars em algumas versoes do
        # .NET Framework - corta em vez de arriscar a bandeja travar.
        if ($tooltip.Length -gt 63) { $tooltip = $tooltip.Substring(0, 60) + "..." }

        Save-LastKnown -FiveHourPct $pct -WeeklyPct $weeklyPct
        Set-TrayIcon -Text "$pct" -BgColor $color -TooltipText $tooltip
    } catch {
        Set-TrayIcon -Text "!" -BgColor ([System.Drawing.Color]::Gray) -TooltipText (T "Error")
    }
}

$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = 5000
$script:timer.Add_Tick({ Update-Usage })

Update-Usage
$script:timer.Start()

[System.Windows.Forms.Application]::Run()
