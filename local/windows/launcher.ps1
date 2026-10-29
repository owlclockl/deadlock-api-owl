param([switch]$AutoStart)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
function Compose {
    & docker compose -f "$PSScriptRoot\compose.yaml" @args
    if ($LASTEXITCODE -ne 0) { throw "Docker Compose failed (exit $LASTEXITCODE). See output above." }
}

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    $dockerBin = Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin'
    $env:Path += ";$dockerBin"
}
function Set-Resume {
    # Current user only; no password or system-wide scheduled task is stored.
    $script = Join-Path $PSScriptRoot 'launcher.ps1'
    $command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File "' + $script + '" -AutoStart'
    New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Force | Out-Null
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'DeadlockOwlSetup' -Value $command
}
function Ensure-Docker {
    Refresh-Path
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Start-Process 'ms-windows-store://pdp/?ProductId=9NBLGGH4NNS'
            throw 'Windows App Installer (winget) is required. Install/update it in the Store window, then run option 1 again.'
        }
        Write-Host 'Installing Docker Desktop. Windows may request administrator approval.'
        Write-Host 'Docker Desktop has its own license terms. Review any installer prompts.'
        & winget install --id Docker.DockerDesktop --exact --source winget --accept-source-agreements --interactive --disable-interactivity
        $installResult = $LASTEXITCODE
        Refresh-Path
        if ($installResult -in 3010, 1641) {
            Set-Resume
            throw 'Installation requires a restart. Restart Windows; setup will continue at your next sign-in. Keep this folder in place.'
        }
        if ($installResult -ne 0) { throw "Docker installation failed ($installResult). Run option 1 to retry." }
        if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
            Set-Resume
            throw 'Docker was installed. Restart Windows to refresh the environment; setup will continue at sign-in.'
        }
    }
    & docker info *> $null
    if ($LASTEXITCODE -eq 0) { return }

    # Enable WSL only when its default Linux environment is not ready. Do not restart automatically.
    & wsl.exe --status *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Enabling WSL2. Approve the Windows administrator prompt.'
        $wsl = Start-Process -FilePath 'wsl.exe' -ArgumentList '--install', '--no-distribution' -Verb RunAs -Wait -PassThru
        if ($wsl.ExitCode -ne 0 -and $wsl.ExitCode -ne 3010 -and $wsl.ExitCode -ne 1641) {
            throw "WSL setup failed ($($wsl.ExitCode)). Check Windows virtualization support and run option 1 again."
        }
        Set-Resume
        throw 'WSL setup completed. Restart Windows; setup will continue at sign-in. Keep this folder in place.'
    }
    $desktop = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
    if (-not (Test-Path -LiteralPath $desktop)) { throw 'Docker Desktop executable not found. Repair Docker Desktop and retry.' }
    Write-Host 'Starting Docker Desktop. Complete its license/onboarding prompts if shown.'
    Start-Process -FilePath $desktop
    Write-Host 'Waiting up to 5 minutes for Docker...'
    $deadline = (Get-Date).AddMinutes(5)
    while ((Get-Date) -lt $deadline) {
        & docker info *> $null
        if ($LASTEXITCODE -eq 0) {
            $os = & docker info --format '{{.OSType}}'
            if ($os -ne 'linux') { throw 'Switch Docker Desktop to Linux containers, then run option 1 again.' }
            return
        }
        Start-Sleep -Seconds 3
    }
    throw 'Docker did not start. Complete Docker Desktop prompts and check virtualization/WSL2, then run option 1 again.'
}
try {
    Write-Host 'Deadlock OWL - local Windows launcher'
    Write-Host '1 - Start local website'
    Write-Host '2 - Stop local website'
    Write-Host '3 - Show website logs'
    Write-Host '4 - Open Deadlock folder (choose your game directory)'
    Write-Host '5 - Launch Deadlock via Steam'
    if ($AutoStart) { $choice = '1' } else { $choice = Read-Host 'Select [1]' }
    if ($choice -notin '', '1', '2', '3', '4', '5') { throw 'Unknown menu option.' }
    switch ($choice) {
        '4' {
            $folder = Read-Host 'Paste the full path to your Deadlock folder (without quotes)'
            if (-not (Test-Path -LiteralPath $folder -PathType Container)) { throw 'Directory not found.' }
            $resolved = (Resolve-Path -LiteralPath $folder).Path
            Start-Process explorer.exe -ArgumentList ('"' + $resolved + '"')
        }
        '5' { Start-Process 'steam://rungameid/1422450' }
        default {
            if ($choice -in '', '1') {
                Ensure-Docker
            } else {
                Refresh-Path
                if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker is not installed yet. Use option 1 first.' }
            }
            switch ($choice) {
                '2' { Compose down }
                '3' { Compose logs --tail 100 -f website }
                { $_ -in '', '1' } {
                    Write-Host 'First launch downloads dependencies and builds the website. This can take a long time.'
                    Compose up -d --build
                    $url = 'http://localhost:3000'
                    $ready = $false
                    for ($i = 0; $i -lt 90; $i++) {
                        try {
                            $response = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 5
                            if ($response.StatusCode -eq 200) { $ready = $true; break }
                        } catch { Start-Sleep -Seconds 2 }
                    }
                    if (-not $ready) {
                        Compose logs --tail 100 website
                        throw 'Website did not become ready. Check the logs above; port 3000 may already be in use.'
                    }
                    Start-Process $url
                    Write-Host 'Website is running. Closing this window does not stop it; use option 2 to stop.'
                }
                default { throw 'Unknown menu option.' }
            }
        }
    }
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
