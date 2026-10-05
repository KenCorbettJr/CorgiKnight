<#
.SYNOPSIS
  Builds the CorgiKnight web (HTML5) export headlessly.

.DESCRIPTION
  Runs Godot in headless mode to export the "Web" preset into build/web/.
  Finds Godot automatically, or pass -Godot "C:\path\to\Godot.exe".

.EXAMPLE
  ./build-web.ps1
  ./build-web.ps1 -Godot "C:\Users\kenne\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
#>
param(
    [string]$Godot = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

# --- Locate the Godot binary ---
if (-not $Godot) {
    $cmd = Get-Command godot, godot4, Godot_v4.7.2-stable_win64 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { $Godot = $cmd.Source }
}
if (-not $Godot) {
    $candidates = @(
        "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe",
        "C:\Program Files\Godot\Godot.exe"
    )
    $Godot = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $Godot -or -not (Test-Path $Godot)) {
    Write-Error "Could not find Godot. Pass -Godot 'C:\path\to\Godot.exe'."
}

Write-Host "Using Godot: $Godot" -ForegroundColor Cyan

# --- Prepare output dir ---
$out = Join-Path $root "build\web"
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Path $out -Force | Out-Null

# --- Import pass (needed on a cold .godot/ cache before the first export) ---
Write-Host "Importing resources ..." -ForegroundColor Cyan
& $Godot --headless --path $root --import | Out-Null

# --- Export ---
Write-Host "Exporting Web preset to build/web/ ..." -ForegroundColor Cyan
& $Godot --headless --path $root --export-release "Web" "$out\index.html"
$code = $LASTEXITCODE

if ($code -ne 0 -or -not (Test-Path "$out\index.html")) {
    Write-Error "Export failed (exit $code). Make sure Web export templates are installed (Editor > Manage Export Templates)."
}

Write-Host "Build complete: $out\index.html" -ForegroundColor Green
Write-Host "Preview locally with:  ./serve-web.ps1" -ForegroundColor Yellow
