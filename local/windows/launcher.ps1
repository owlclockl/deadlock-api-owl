$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
function Compose {
    & docker compose -f "$PSScriptRoot\compose.yaml" @args
    if ($LASTEXITCODE -ne 0) { throw "Docker Compose failed (exit $LASTEXITCODE). See output above." }
}
try {
    Write-Host 'Deadlock OWL - local Windows launcher'
    Write-Host '1 - Start local website'
    Write-Host '2 - Stop local website'
    Write-Host '3 - Show website logs'
    Write-Host '4 - Open Deadlock folder (choose your game directory)'
    Write-Host '5 - Launch Deadlock via Steam'
    $choice = Read-Host 'Select [1]'
    switch ($choice) {
        '4' {
            $folder = Read-Host 'Paste the full path to your Deadlock folder (without quotes)'
            if (-not (Test-Path -LiteralPath $folder -PathType Container)) { throw 'Directory not found.' }
            $resolved = (Resolve-Path -LiteralPath $folder).Path
            Start-Process explorer.exe -ArgumentList ('"' + $resolved + '"')
        }
        '5' { Start-Process 'steam://rungameid/1422450' }
        default {
            if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
                throw 'Install Docker Desktop for Windows (WSL2 backend), start it, then run this launcher again: https://www.docker.com/products/docker-desktop/'
            }
            & docker info *> $null
            if ($LASTEXITCODE -ne 0) { throw 'Start Docker Desktop and enable Linux containers, then try again.' }
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
