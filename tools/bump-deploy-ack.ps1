param([string] $Value = "")
$ErrorActionPreference = "Stop"
$root = git rev-parse --show-toplevel 2>$null
if (-not $root) { $root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path }
if (-not $Value) {
    $Value = [DateTime]::UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
}
function Write-Ack([string] $Path) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { return }
    [System.IO.File]::WriteAllText($Path, "$Value`n", [System.Text.UTF8Encoding]::new($false))
    Write-Host "  $Path"
}
Write-Host "deploy.ack <- $Value"
foreach ($env in @("development", "production")) {
    $envDir = Join-Path $root $env
    if (-not (Test-Path -LiteralPath $envDir -PathType Container)) { continue }
    Write-Ack (Join-Path $envDir "deploy.ack")
    $cronDir = Join-Path $envDir "cron-jobs"
    if (Test-Path -LiteralPath $cronDir -PathType Container) {
        Write-Ack (Join-Path $cronDir "deploy.ack")
    }
    foreach ($wl in @("workload-common", "workload-vault", "workload-obs")) {
        $wlDir = Join-Path $envDir $wl
        if (-not (Test-Path -LiteralPath $wlDir -PathType Container)) { continue }
        Write-Ack (Join-Path $wlDir "deploy.ack")
        Get-ChildItem -LiteralPath $wlDir -Directory | ForEach-Object {
            Write-Ack (Join-Path $_.FullName "deploy.ack")
        }
    }
}
Write-Host "Feito."