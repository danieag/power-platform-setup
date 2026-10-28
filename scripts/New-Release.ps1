#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $root 'dist'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$archive = Join-Path $destination 'power-platform-setup-windows.zip'
# Explicit public-file allowlist: never package workspace state or personal configuration.
$files = @('Setup.cmd', 'Setup.ps1', 'README.md', 'AGENTS.md', 'LICENSE', 'skills')
$paths = $files | ForEach-Object { Join-Path $root $_ }
Compress-Archive -LiteralPath $paths -DestinationPath $archive -Force
Get-FileHash -LiteralPath $archive -Algorithm SHA256 |
    ForEach-Object { "$($_.Hash.ToLowerInvariant())  power-platform-setup-windows.zip" } |
    Set-Content -LiteralPath "$archive.sha256" -Encoding ASCII
Write-Host "Created $archive and its SHA256 checksum."
