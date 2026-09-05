# Builds the release binary and wraps it in the Inno Setup installer.
#   powershell -ExecutionPolicy Bypass -File tools\build-installer.ps1
# Output: dist\Quotty-Setup.exe
param([string]$Iscc)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# Single source of truth for the version: Cargo.toml.
$version = (Select-String -Path "Cargo.toml" -Pattern '^version\s*=\s*"(.+)"' |
            Select-Object -First 1).Matches[0].Groups[1].Value
Write-Output "Quotty $version"

if (-not $Iscc) {
    $compilerCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    $candidates = @(
        if ($compilerCommand) { $compilerCommand.Source }
        Join-Path $root 'target\installer-tools\Inno Setup 6\ISCC.exe'
        if (${env:ProgramFiles(x86)}) { Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe' }
        if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe' }
        if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe' }
        'D:\Programs\Inno Setup 6\ISCC.exe'
    )
    $Iscc = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
}
if (-not $Iscc -or -not (Test-Path -LiteralPath $Iscc -PathType Leaf)) {
    throw 'Inno Setup not found. Install Inno Setup 6 or pass -Iscc <path to ISCC.exe>.'
}

cargo build --release --locked
if ($LASTEXITCODE -ne 0) { throw "cargo build failed" }

New-Item -ItemType Directory -Force -Path dist | Out-Null
& $Iscc "/DAppVersion=$version" "installer\quotty.iss"
if ($LASTEXITCODE -ne 0) { throw "ISCC failed" }

$setup = "dist\Quotty-Setup.exe"
"{0}  {1:N2} MB" -f $setup, ((Get-Item $setup).Length / 1MB)
