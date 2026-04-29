param(
  [string]$DeviceId,
  [switch]$NoBackend,
  [switch]$NoFlutter
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

function Test-Tool {
  param([string]$Name)

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "'$Name' command was not found. Please check your PATH."
  }
}

function Test-Health {
  param([string]$Url)

  try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
    return $response.StatusCode -ge 200 -and $response.StatusCode -lt 300
  } catch {
    return $false
  }
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$apiProject = Join-Path $root 'backend\src\PulseCity.Api\PulseCity.Api.csproj'
$healthUrl = 'http://127.0.0.1:5275/api/health'
$backendProcess = $null
$backendOwnedByScript = $false

Test-Tool 'dotnet'
Test-Tool 'flutter'

try {
  if (-not $NoBackend) {
    if (Test-Health -Url $healthUrl) {
      Write-Host 'Backend is already running. Reusing the existing process.' -ForegroundColor Cyan
    } else {
      $logRoot = Join-Path $env:TEMP 'PulseCity'
      New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

      $stdoutLog = Join-Path $logRoot 'backend.stdout.log'
      $stderrLog = Join-Path $logRoot 'backend.stderr.log'

      Remove-Item $stdoutLog, $stderrLog -ErrorAction SilentlyContinue

      Write-Host 'Starting backend...' -ForegroundColor Cyan
      $backendProcess = Start-Process `
        -FilePath 'dotnet' `
        -ArgumentList @('run', '--project', $apiProject) `
        -WorkingDirectory $root `
        -PassThru `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError $stderrLog

      $backendOwnedByScript = $true

      $ready = $false
      for ($attempt = 0; $attempt -lt 60; $attempt++) {
        Start-Sleep -Seconds 1

        if ($backendProcess.HasExited) {
          $stdout = if (Test-Path $stdoutLog) { Get-Content $stdoutLog -Tail 40 } else { @() }
          $stderr = if (Test-Path $stderrLog) { Get-Content $stderrLog -Tail 40 } else { @() }
          throw @(
            'Backend process exited unexpectedly.',
            '--- stdout ---',
            ($stdout -join [Environment]::NewLine),
            '--- stderr ---',
            ($stderr -join [Environment]::NewLine)
          ) -join [Environment]::NewLine
        }

        if (Test-Health -Url $healthUrl) {
          $ready = $true
          break
        }
      }

      if (-not $ready) {
        throw "Backend did not become healthy in time: $healthUrl"
      }

      Write-Host "Backend is ready: $healthUrl" -ForegroundColor Green
    }
  }

  if ($NoFlutter) {
    Write-Host 'Flutter was skipped (-NoFlutter).' -ForegroundColor Yellow
    return
  }

  $flutterArgs = @('run')
  if ($DeviceId) {
    $flutterArgs += @('-d', $DeviceId)
  }

  Write-Host "Starting Flutter: flutter $($flutterArgs -join ' ')" -ForegroundColor Cyan
  & flutter @flutterArgs
  if ($LASTEXITCODE -ne 0) {
    throw "flutter $($flutterArgs -join ' ') failed with exit code $LASTEXITCODE"
  }
} finally {
  if ($backendOwnedByScript -and $backendProcess -and -not $backendProcess.HasExited) {
    Write-Host 'Stopping backend...' -ForegroundColor DarkYellow
    Stop-Process -Id $backendProcess.Id -Force
  }
}
