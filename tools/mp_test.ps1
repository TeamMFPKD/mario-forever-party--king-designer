<#
    MF: MP - three-instance local multiplayer test launcher

    Modes
      human : windowed host + 2 clients. Each instance auto-fills name/port and presses
              "host"/"join" by itself; a human then presses "ready" + "start" and plays.
      auto  : headless host + 2 headless clients, auto ready + auto start + auto exit,
              then this script checks markers in the per-instance logs and prints PASS/FAIL.

    Examples
      tools\mp_test.bat                          # human mode (3 windows)
      tools\mp_test.bat auto                     # automated smoke test
      tools\mp_test.bat auto -ShowWindows        # automated test but keep windows visible
      tools\mp_test.bat human -Pads 0,1,2        # map gamepad device 0/1/2 to host/c1/c2
      tools\mp_test.bat human -WinSize 800x450
      tools\mp_test.bat -Stop                    # kill instances started by this script

    The very same per-instance arguments can be used in the editor
    (Debug -> Customize Run Instances, per-instance "override main run args"):

      host : -- --mp-role=host --mp-name=test1 --mp-port=8914 --mp-no-ready-timeout --mp-win=640x360+0+0
      c1   : -- --mp-role=join --mp-name=test2 --mp-ip=127.0.0.1 --mp-port=8914 --mp-no-ready-timeout --mp-win=640x360+640+0
      c2   : -- --mp-role=join --mp-name=test3 --mp-ip=127.0.0.1 --mp-port=8914 --mp-no-ready-timeout --mp-win=640x360+1280+0

    Notes
      * Player names MUST be different: level files are saved as
        user://mfmp_<time>_<name>_<unique_id>.lvl and the time part is shared by all players.
      * Keyboard events go to the focused window only. For three simultaneous players use
        -Pads (three gamepads) or run instances on separate machines.
      * --mp-no-ready-timeout disables the "unready after 10s unfocused / 20s no input" rule,
        which otherwise makes a three-window lobby impossible to start.
#>
[CmdletBinding()]
param(
    [ValidateSet('human', 'auto')]
    [string]$Mode = 'human',
    [int]$Port = 8914,
    [string]$Ip = '127.0.0.1',
    [string]$WinSize = '640x360',
    [int[]]$Pads = @(),
    [string]$GodotPath = '',
    [switch]$ShowWindows,
    [switch]$KeepRunning,
    [switch]$Stop
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $PSScriptRoot 'mp_test_logs'
$TestNames = @('test1', 'test2', 'test3')

function Resolve-GodotPath {
    param([string]$Explicit, [switch]$Console)
    $software = 'D:\Windows\GreenSweet\Game\Software'
    $candidates = New-Object System.Collections.Generic.List[string]
    if ($Explicit) { $candidates.Add($Explicit) }
    if ($env:GODOT_BIN) { $candidates.Add($env:GODOT_BIN) }
    if ($Console) {
        $candidates.Add((Join-Path $software 'Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'))
    }
    $candidates.Add((Join-Path $software 'Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe'))
    $candidates.Add((Join-Path $software 'Godot_v4.7.2-stable_win64.exe'))
    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath $path)) { return $path }
    }
    $cmd = Get-Command 'godot' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'Godot executable not found. Pass -GodotPath <exe> or set GODOT_BIN.'
}

function Stop-TestInstances {
    $stopped = 0
    $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -like 'Godot*' -and $_.CommandLine -and $_.CommandLine -like '*--mp-role=*'
    }
    foreach ($proc in $procs) {
        try {
            Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
            $stopped++
        } catch {
            # already gone
        }
    }
    return $stopped
}

function Clear-TestLogs {
    foreach ($name in $TestNames) {
        $path = Join-Path $LogDir "$name.log"
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}

function Start-TestInstance {
    param(
        [string]$Name,
        [string]$Role,
        [string]$WindowSpec,
        [string[]]$ExtraArgs = @(),
        [string]$PadDevice = '',
        [switch]$Headless
    )
    $argList = New-Object System.Collections.Generic.List[string]
    if ($Headless) { $argList.Add('--headless') }
    $argList.Add('--log-file')
    $argList.Add("tools/mp_test_logs/$Name.log")
    $argList.Add('--')
    $argList.Add("--mp-role=$Role")
    $argList.Add("--mp-name=$Name")
    $argList.Add("--mp-port=$Port")
    $argList.Add("--mp-win=$WindowSpec")
    $argList.Add('--mp-no-ready-timeout')
    if ($Role -eq 'join') { $argList.Add("--mp-ip=$Ip") }
    if ($PadDevice -ne '') { $argList.Add("--mp-pad=$PadDevice") }
    foreach ($extra in $ExtraArgs) { $argList.Add($extra) }

    $startArgs = @{
        FilePath         = $script:GodotExe
        WorkingDirectory = $ProjectRoot
        ArgumentList     = $argList.ToArray()
        PassThru         = $true
    }
    if ($Headless) { $startArgs['WindowStyle'] = 'Hidden' }
    return Start-Process @startArgs
}

function Wait-LogText {
    param(
        [string]$Name,
        [string]$Text,
        [int]$TimeoutSeconds
    )
    $path = Join-Path $LogDir "$Name.log"
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $path) {
            $content = Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue
            if ($content -and $content.Contains($Text)) { return $true }
        }
        Start-Sleep -Milliseconds 400
    }
    return $false
}

function Show-LogTail {
    param([string]$Name, [int]$Lines = 20)
    $path = Join-Path $LogDir "$Name.log"
    Write-Host "--- $Name.log (last $Lines lines) ---" -ForegroundColor DarkGray
    if (Test-Path -LiteralPath $path) {
        Get-Content -LiteralPath $path -Tail $Lines | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host '  <no log file>'
    }
}

function Assert-PortFree {
    $listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($listeners) {
        $owners = ($listeners | Select-Object -ExpandProperty OwningProcess -Unique) -join ', '
        Write-Warning "Port $Port is already in use (PID: $owners). The host instance will fail to listen."
    }
}

# ---------------------------------------------------------------- entry point

if ($Stop) {
    $count = Stop-TestInstances
    Write-Host "Stopped $count test instance(s)."
    exit 0
}

if ($WinSize -notmatch '^\d+x\d+$') {
    throw "Invalid -WinSize '$WinSize'. Expected e.g. 640x360."
}
$null = $WinSize -match '^(\d+)x(\d+)$'
$winWidth = [int]$Matches[1]
$winHeight = [int]$Matches[2]

if ($Pads.Count -ne 0 -and $Pads.Count -ne 3) {
    throw 'Use -Pads with exactly three device ids, e.g. -Pads 0,1,2'
}

$headless = ($Mode -eq 'auto') -and (-not $ShowWindows)
$script:GodotExe = Resolve-GodotPath -Explicit $GodotPath -Console:$headless

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

if ($Mode -eq 'auto') {
    Write-Host '=== MF: MP automated 3-instance test ===' -ForegroundColor Cyan
} else {
    Write-Host '=== MF: MP human 3-instance test ===' -ForegroundColor Cyan
}
Write-Host "project : $ProjectRoot"
Write-Host "godot   : $script:GodotExe"
Write-Host "mode    : $Mode (headless=$headless)"
Write-Host "port    : $Port"
Write-Host "logs    : $LogDir"

$stopped = Stop-TestInstances
if ($stopped -gt 0) { Write-Host "stopped $stopped leftover instance(s)" -ForegroundColor DarkYellow }
Clear-TestLogs
Assert-PortFree
Write-Host ''

$positions = @(
    "0",
    "$winWidth",
    "$($winWidth * 2)"
)
$windowSpecs = @(
    "${winWidth}x${winHeight}+$($positions[0])+0",
    "${winWidth}x${winHeight}+$($positions[1])+0",
    "${winWidth}x${winHeight}+$($positions[2])+0"
)
$padArgs = @('', '', '')
if ($Pads.Count -eq 3) {
    $padArgs = @([string]$Pads[0], [string]$Pads[1], [string]$Pads[2])
}

$autoArgs = @(
    '--mp-auto-ready',
    '--mp-auto-start',
    '--mp-expect=3',
    '--mp-edit-seconds=10',
    '--mp-auto-exit'
)
$roleArgs = @()
if ($Mode -eq 'auto') { $roleArgs = $autoArgs }

# host must be listening before clients start; join has retry but this keeps logs clean
$hostProc = Start-TestInstance -Name 'test1' -Role 'host' -WindowSpec $windowSpecs[0] `
    -ExtraArgs $roleArgs -PadDevice $padArgs[0] -Headless:$headless
Write-Host 'started host  : test1' -ForegroundColor Green

if ($Mode -eq 'auto') {
    $hostUp = Wait-LogText -Name 'test1' -Text 'MPTEST] host listening' -TimeoutSeconds 45
    if (-not $hostUp) {
        Write-Host 'FAIL: host did not report listening within 45s.' -ForegroundColor Red
        Show-LogTail -Name 'test1'
        if (-not $KeepRunning) { $null = Stop-TestInstances }
        exit 1
    }
} else {
    Start-Sleep -Seconds 3
}

$client1Proc = Start-TestInstance -Name 'test2' -Role 'join' -WindowSpec $windowSpecs[1] `
    -ExtraArgs $roleArgs -PadDevice $padArgs[1] -Headless:$headless
$client2Proc = Start-TestInstance -Name 'test3' -Role 'join' -WindowSpec $windowSpecs[2] `
    -ExtraArgs $roleArgs -PadDevice $padArgs[2] -Headless:$headless
Write-Host 'started client: test2 (id will be 2)'
Write-Host 'started client: test3 (id will be 3)'
Write-Host ''

if ($Mode -eq 'human') {
    Write-Host 'Windows are tiled left-to-right: test1 (host) | test2 | test3' -ForegroundColor Yellow
    Write-Host 'Each instance already pressed host/join by itself. Now:' -ForegroundColor Yellow
    Write-Host '  1. In every window press "准备完毕" (auto-unready is disabled by the launch args).'
    Write-Host '  2. In the host window press "开始".'
    Write-Host '  3. Click a window to give it keyboard focus; use -Pads 0,1,2 for three gamepads.'
    Write-Host ''
    Write-Host 'Editor equivalent (Debug -> Customize Run Instances, per-instance args):'
    for ($i = 0; $i -lt 3; $i++) {
        $role = if ($i -eq 0) { 'host' } else { 'join' }
        $name = $TestNames[$i]
        $ipPart = if ($role -eq 'join') { " --mp-ip=$Ip" } else { '' }
        Write-Host ("  {0} : -- --mp-role={1} --mp-name={2}{3} --mp-port={4} --mp-no-ready-timeout --mp-win={5}" -f `
            $name, $role, $name, $ipPart, $Port, $windowSpecs[$i])
    }
    Write-Host ''
    Write-Host "Process ids: host=$($hostProc.Id) client1=$($client1Proc.Id) client2=$($client2Proc.Id)"
    Write-Host 'Stop them with: tools\mp_test.bat -Stop'
    exit 0
}

# ------------------------------------------------------------------ auto mode
$client1Joined = Wait-LogText -Name 'test2' -Text 'MPTEST] joined' -TimeoutSeconds 60
$client2Joined = Wait-LogText -Name 'test3' -Text 'MPTEST] joined' -TimeoutSeconds 60
$started = Wait-LogText -Name 'test1' -Text 'MPTEST] all players ready' -TimeoutSeconds 90
$exited = $false
if ($started) {
    $exited = Wait-LogText -Name 'test1' -Text 'MPTEST] quit after game_start' -TimeoutSeconds 45
}

$allPass = $client1Joined -and $client2Joined -and $started -and $exited

Write-Host ''
Write-Host '--- auto test result ---'
Write-Host ("test2 joined      : {0}" -f $(if ($client1Joined) { 'PASS' } else { 'FAIL' })) -ForegroundColor $(if ($client1Joined) { 'Green' } else { 'Red' })
Write-Host ("test3 joined      : {0}" -f $(if ($client2Joined) { 'PASS' } else { 'FAIL' })) -ForegroundColor $(if ($client2Joined) { 'Green' } else { 'Red' })
Write-Host ("3 players ready   : {0}" -f $(if ($started) { 'PASS' } else { 'FAIL' })) -ForegroundColor $(if ($started) { 'Green' } else { 'Red' })
Write-Host ("game started/exit : {0}" -f $(if ($exited) { 'PASS' } else { 'FAIL' })) -ForegroundColor $(if ($exited) { 'Green' } else { 'Red' })

if (-not $allPass) {
    foreach ($name in $TestNames) { Show-LogTail -Name $name }
}

if (-not $KeepRunning) { $null = Stop-TestInstances }

if ($allPass) {
    Write-Host 'PASS' -ForegroundColor Green
    exit 0
}
Write-Host 'FAIL' -ForegroundColor Red
exit 1
