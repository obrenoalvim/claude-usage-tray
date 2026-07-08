$claudeConfigDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".claude" }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:snapshotPath = Join-Path $claudeConfigDir "cache\usage-snapshot.json"
$script:freshnessMs  = 15 * 60 * 1000   # ignore snapshot older than 15 min

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

    $hicon = $bmp.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($hicon)
    $bmp.Dispose()
    return $icon
}

$script:trayIcon = New-Object System.Windows.Forms.NotifyIcon
$script:trayIcon.Icon = New-PercentIcon -Text "?" -BgColor ([System.Drawing.Color]::Gray)
$script:trayIcon.Text = "Claude - 5h usage"
$script:trayIcon.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$exitItem = $menu.Items.Add("Sair")
$exitItem.Add_Click({
    $script:trayIcon.Visible = $false
    $script:timer.Stop()
    [System.Windows.Forms.Application]::Exit()
})
$script:trayIcon.ContextMenuStrip = $menu

function Update-Usage {
    if (-not (Test-Path $script:snapshotPath)) {
        $script:trayIcon.Icon = New-PercentIcon -Text "-" -BgColor ([System.Drawing.Color]::Gray)
        $script:trayIcon.Text = "Claude - 5h usage: sem dado"
        return
    }
    try {
        $json = Get-Content $script:snapshotPath -Raw | ConvertFrom-Json
        $updatedAt = [DateTimeOffset]::Parse($json.updated_at).ToUnixTimeMilliseconds()
        $nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $pct = $json.five_hour.used_percentage

        if (($nowMs - $updatedAt) -gt $script:freshnessMs -or $null -eq $pct) {
            $script:trayIcon.Icon = New-PercentIcon -Text "-" -BgColor ([System.Drawing.Color]::Gray)
            $script:trayIcon.Text = "Claude - 5h usage: sem dado"
            return
        }

        $pct = [int]$pct
        $color = [System.Drawing.Color]::SeaGreen
        if ($pct -ge 90) { $color = [System.Drawing.Color]::Crimson }
        elseif ($pct -ge 70) { $color = [System.Drawing.Color]::DarkOrange }

        $resetInfo = ""
        if ($json.five_hour.resets_at) {
            $resetsAt = [DateTimeOffset]::Parse($json.five_hour.resets_at)
            $remaining = $resetsAt.ToUniversalTime() - [DateTimeOffset]::UtcNow
            if ($remaining.TotalMinutes -gt 0) {
                $resetInfo = " (reseta em $([int]$remaining.TotalHours)h $($remaining.Minutes)min)"
            }
        }

        $script:trayIcon.Icon = New-PercentIcon -Text "$pct" -BgColor $color
        $script:trayIcon.Text = "Claude - 5h usage: $pct%$resetInfo"
    } catch {
        $script:trayIcon.Icon = New-PercentIcon -Text "!" -BgColor ([System.Drawing.Color]::Gray)
        $script:trayIcon.Text = "Claude - 5h usage: erro lendo dado"
    }
}

$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = 5000
$script:timer.Add_Tick({ Update-Usage })

Update-Usage
$script:timer.Start()

[System.Windows.Forms.Application]::Run()
