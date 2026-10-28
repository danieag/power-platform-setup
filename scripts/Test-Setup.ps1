#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failures = 0
$passed = 0

function Assert-Equal {
    param($Actual, $Expected)
    if ($Actual -cne $Expected) { throw "Expected '$Expected', got '$Actual'." }
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Pattern)
    try { & $Action } catch {
        if ($_.Exception.Message -notmatch $Pattern) { throw }
        return
    }
    throw "Expected an exception matching '$Pattern'."
}

function Test-Case {
    param([string]$Name, [scriptblock]$Action)
    try {
        # Isolate all function mocks in a child scope. No installed tools are executed.
        & {
            . (Join-Path $root 'Setup.ps1')
            & $Action 6>$null
        }
        $script:passed++
        Write-Host "PASS $Name"
    } catch {
        $script:failures++
        Write-Host "FAIL $Name - $($_.Exception.Message)" -ForegroundColor Red
    }
}

function New-TestState {
    param([string[]]$Ready = @(), [switch]$Azure)
    $ids = @('git', 'node', 'dotnet', 'pac')
    if ($Azure) { $ids += 'azure' }
    foreach ($id in $ids) {
        [pscustomobject]@{
            Id = $id; Name = $id; Ready = $id -in $Ready
            Version = [version]'24.1.0'; Path = "C:\test\$id.exe"; Requirement = 'test'
        }
    }
}

Test-Case 'all PowerShell files parse' {
    foreach ($file in Get-ChildItem -LiteralPath $root -Filter '*.ps1' -Recurse) {
        $tokens = $null
        $errors = $null
        [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
        if ($errors.Count) { throw ($errors.Message -join '; ') }
    }
}

Test-Case 'version parsing handles vendor suffixes and rejects garbage' {
    Assert-Equal (ConvertTo-ToolVersion 'git version 2.56.0.windows.4') ([version]'2.56.0')
    Assert-Equal (ConvertTo-ToolVersion '2.11.2+g47bc199') ([version]'2.11.2')
    Assert-Equal (ConvertTo-ToolVersion 'unknown') $null
}

Test-Case 'architecture gate rejects unsupported operating systems' {
    $old = $env:OS
    try {
        $env:OS = 'not-windows'
        Assert-Throws { Get-SetupArchitecture } 'Windows only'
    } finally { $env:OS = $old }
}

Test-Case 'check-only cannot reach mutating, network or prompt operations' {
    function Get-SetupArchitecture {}
    function Get-SetupState { New-TestState }
    function Install-SetupTool { throw 'INSTALL FORBIDDEN' }
    function Update-SetupPath { throw 'PATH CHANGE FORBIDDEN' }
    function Invoke-WebRequest { throw 'DOWNLOAD FORBIDDEN' }
    function Invoke-RestMethod { throw 'NETWORK FORBIDDEN' }
    function Start-Process { throw 'PROCESS FORBIDDEN' }
    function Invoke-SetupNative { throw 'CLI FORBIDDEN' }
    function New-Item { throw 'WRITE FORBIDDEN' }
    function Read-Host { throw 'PROMPT FORBIDDEN' }
    $pathBefore = $env:PATH
    Assert-Equal (Invoke-Setup -CheckOnly) 1
    Assert-Equal $env:PATH $pathBefore
}

Test-Case 'real local inventory never invokes a CLI or a network/write operation' {
    function Invoke-WebRequest { throw 'DOWNLOAD FORBIDDEN' }
    function Invoke-RestMethod { throw 'NETWORK FORBIDDEN' }
    function Start-Process { throw 'PROCESS FORBIDDEN' }
    function Invoke-SetupNative { throw 'CLI FORBIDDEN' }
    function New-Item { throw 'WRITE FORBIDDEN' }
    $state = @(Get-SetupState -Azure)
    Assert-Equal ($state.Id -join ',') 'git,node,dotnet,pac,azure'
}

Test-Case 'inventory recognizes compatible binaries, bundled npm and the SDK rather than runtime' {
    function Find-SetupExecutable { param($Name, $Candidates) "C:\fixture\$Name" }
    function Get-BinaryVersion {
        param($Path)
        if ($Path -like '*git.exe') { return [version]'2.56.0' }
        if ($Path -like '*node.exe') { return [version]'22.18.0' }
        if ($Path -like '*pac.exe') { return [version]'2.11.2' }
    }
    function Test-Path { $true }
    function Get-Content { '{"version":"10.9.0"}' }
    function Get-ChildItem {
        [pscustomobject]@{ Name = '10.0.100'; FullName = 'C:\fixture\sdk\10.0.100' }
        [pscustomobject]@{ Name = '11.0.100'; FullName = 'C:\fixture\sdk\11.0.100' }
        [pscustomobject]@{ Name = '10.0.200-preview'; FullName = 'C:\fixture\sdk\10.0.200-preview' }
    }
    $state = @(Get-SetupState)
    Assert-Equal (@($state | Where-Object { -not $_.Ready }).Count) 0
    Assert-Equal ($state | Where-Object Id -eq 'dotnet').Version ([version]'10.0.100')
}

Test-Case 'inventory rejects unsupported Node majors, absent npm, and runtime-only dotnet' {
    function Find-SetupExecutable { param($Name, $Candidates) "C:\fixture\$Name" }
    function Get-BinaryVersion { [version]'25.0.0' }
    function Test-Path { $false }
    $state = @(Get-SetupState)
    Assert-Equal ($state | Where-Object Id -eq 'node').Ready $false
    Assert-Equal ($state | Where-Object Id -eq 'dotnet').Ready $false
}

Test-Case 'Node compatibility includes the Copilot Studio MCP minimum without accepting other majors' {
    function Find-SetupExecutable { param($Name, $Candidates) "C:\fixture\$Name" }
    function Get-BinaryVersion { $script:nodeUnderTest }
    function Test-Path { $true }
    function Get-Content { '{"version":"10.9.0"}' }
    function Get-ChildItem {}
    foreach ($case in @(
        @{ Version = '22.17.0'; Ready = $false },
        @{ Version = '22.18.0'; Ready = $true },
        @{ Version = '24.0.0'; Ready = $true },
        @{ Version = '25.0.0'; Ready = $false })) {
        $script:nodeUnderTest = [version]$case.Version
        $node = Get-SetupState | Where-Object Id -eq 'node'
        Assert-Equal $node.Ready $case.Ready
    }
}

Test-Case 'noninteractive mode requires both install and accept' {
    function Get-SetupArchitecture {}
    function Get-SetupState { New-TestState }
    function Read-Host { throw 'PROMPT FORBIDDEN' }
    function Install-SetupTool { throw 'INSTALL FORBIDDEN' }
    Assert-Equal (Invoke-Setup -NonInteractive) 2
    Assert-Equal (Invoke-Setup -Install -NonInteractive) 2
    Assert-Equal (Invoke-Setup -Accept -NonInteractive) 2
    Assert-Equal (Invoke-Setup -CheckOnly -Install -Accept) 2
}

Test-Case 'interactive initial launch requires exact explicit approval' {
    function Get-SetupArchitecture {}
    function Get-SetupState { New-TestState }
    function Read-Host { 'yes' }
    function Install-SetupTool { throw 'INSTALL FORBIDDEN' }
    Assert-Equal (Invoke-Setup) 2
}

Test-Case 'approved installation obeys order and verifies each tool' {
    $script:installed = @()
    $script:verified = @()
    function Get-SetupArchitecture {}
    function Get-SetupState { param([switch]$Azure) New-TestState -Ready $script:installed -Azure:$Azure }
    function Update-SetupPath {}
    function Install-SetupTool { param($Id) $script:installed += $Id; return $false }
    function Confirm-InstalledTool { param($Id, $State) $script:verified += $Id }
    Assert-Equal (Invoke-Setup -Install -Accept -NonInteractive -IncludeAzureCli) 0
    Assert-Equal ($script:installed -join ',') 'git,node,dotnet,pac,azure'
    Assert-Equal ($script:verified -join ',') 'git,node,dotnet,pac,azure'
}

Test-Case 'safe rerun skips compatible tools and does not add Azure by default' {
    $script:installed = @('git', 'node', 'dotnet', 'pac')
    function Get-SetupArchitecture {}
    function Get-SetupState { New-TestState -Ready $script:installed }
    function Install-SetupTool { throw 'INSTALL FORBIDDEN' }
    function Update-SetupPath { throw 'PATH CHANGE FORBIDDEN' }
    function Read-Host { throw 'PROMPT FORBIDDEN' }
    Assert-Equal (Invoke-Setup -CheckOnly) 0
    Assert-Equal (Invoke-Setup -Install -Accept -NonInteractive) 0
}

Test-Case 'partial rerun installs only missing tools' {
    $script:installed = @('git', 'dotnet')
    $script:added = @()
    function Get-SetupArchitecture {}
    function Get-SetupState { New-TestState -Ready $script:installed }
    function Update-SetupPath {}
    function Install-SetupTool { param($Id) $script:installed += $Id; $script:added += $Id; $false }
    function Confirm-InstalledTool {}
    Assert-Equal (Invoke-Setup -Install -Accept -NonInteractive) 0
    Assert-Equal ($script:added -join ',') 'node,pac'
}

Test-Case 'first failure prevents later installations' {
    $script:attempted = @()
    function Get-SetupArchitecture {}
    function Get-SetupState { New-TestState }
    function Update-SetupPath {}
    function Install-SetupTool { param($Id) $script:attempted += $Id; throw 'simulated failure' }
    Assert-Equal (Invoke-Setup -Install -Accept -NonInteractive) 3
    Assert-Equal ($script:attempted -join ',') 'git'
}

Test-Case 'restart requirement stops the chain without reboot' {
    $script:attempted = @()
    function Get-SetupArchitecture {}
    function Get-SetupState { New-TestState }
    function Update-SetupPath {}
    function Install-SetupTool { param($Id) $script:attempted += $Id; $true }
    function Confirm-InstalledTool { throw 'VERIFY BEFORE RESTART FORBIDDEN' }
    Assert-Equal (Invoke-Setup -Install -Accept -NonInteractive) 3010
    Assert-Equal ($script:attempted -join ',') 'git'
}

Test-Case 'PATH refresh preserves inherited entries and does not persist changes' {
    $old = $env:PATH
    try {
        $env:PATH = 'C:\unique-inherited;C:\second'
        Update-SetupPath
        Assert-Equal ($env:PATH.StartsWith('C:\unique-inherited;C:\second;')) $true
        Assert-Equal (($env:PATH -split ';') -contains "$env:USERPROFILE\.dotnet\tools") $true
    } finally { $env:PATH = $old }
}

Test-Case 'URL allowlist rejects untrusted, HTTP and credential-bearing sources' {
    Assert-OfficialUrl 'https://nodejs.org/dist/index.json'
    Assert-Throws { Assert-OfficialUrl 'https://example.com/installer.exe' } 'Refusing'
    Assert-Throws { Assert-OfficialUrl 'http://nodejs.org/installer.exe' } 'Refusing'
    Assert-Throws { Assert-OfficialUrl 'https://user:pass@nodejs.org/installer.exe' } 'Refusing'
    Assert-Throws { Assert-OfficialUrl 'https://nodejs.org:8443/installer.exe' } 'Refusing'
}

Test-Case 'Git metadata without checksum fails closed' {
    function Get-OfficialJson {
        [pscustomobject]@{ assets = @([pscustomobject]@{
            name = 'Git-2.56.0-64-bit.exe'; digest = ''; browser_download_url = 'https://github.com/test'
        }) }
    }
    Assert-Throws { Get-InstallerSpec 'git' } 'SHA256'
}

Test-Case 'Git metadata selects only the x64 installer and its SHA256' {
    function Get-OfficialJson {
        [pscustomobject]@{ assets = @(
            [pscustomobject]@{ name = 'Git-2.56.0.4-arm64.exe'; digest = 'ignored'; browser_download_url = 'ignored' },
            [pscustomobject]@{
                name = 'Git-2.56.0.4-64-bit.exe'; digest = ('sha256:' + ('a' * 64))
                browser_download_url = 'https://github.com/git-for-windows/git/releases/download/test/git.exe'
            }) }
    }
    $spec = Get-InstallerSpec 'git'
    Assert-Equal $spec.Hash ('a' * 64)
    Assert-Equal $spec.Admin $false
}

Test-Case 'Node metadata selects stable 24 LTS and checksums for its exact MSI' {
    function Get-OfficialJson {
        @(
            [pscustomobject]@{ version = 'v26.1.0'; lts = $false },
            [pscustomobject]@{ version = 'v24.10.0'; lts = 'Krypton' },
            [pscustomobject]@{ version = 'v22.18.0'; lts = 'Jod' })
    }
    function Invoke-WebRequest {
        [pscustomobject]@{ Content = (('b' * 64) + '  node-v24.10.0-x64.msi') }
    }
    $spec = Get-InstallerSpec 'node'
    Assert-Equal $spec.Url 'https://nodejs.org/dist/v24.10.0/node-v24.10.0-x64.msi'
    Assert-Equal $spec.Hash ('b' * 64)
    function Invoke-WebRequest { [pscustomobject]@{ Content = 'no checksum' } }
    Assert-Throws { Get-InstallerSpec 'node' } 'No SHA256'
}

Test-Case '.NET metadata selects the latest SDK installer rather than a runtime' {
    function Get-OfficialJson {
        [pscustomobject]@{
            'latest-sdk' = '10.0.100'
            releases = @([pscustomobject]@{
                sdk = [pscustomobject]@{
                    version = '10.0.100'
                    files = @(
                        [pscustomobject]@{ rid = 'win-x64'; name = 'dotnet-sdk-win-x64.exe'; hash = ('c' * 128); url = 'https://builds.dotnet.microsoft.com/sdk.exe' },
                        [pscustomobject]@{ rid = 'win-arm64'; name = 'dotnet-sdk-win-arm64.exe'; hash = ('d' * 128); url = 'https://builds.dotnet.microsoft.com/arm.exe' })
                }
            })
        }
    }
    $spec = Get-InstallerSpec 'dotnet'
    Assert-Equal $spec.Url 'https://builds.dotnet.microsoft.com/sdk.exe'
    Assert-Equal $spec.Hash ('c' * 128)
    Assert-Equal $spec.Algorithm 'SHA512'
}

Test-Case 'checksum and signature verification fail closed' {
    function Get-FileHash { [pscustomobject]@{ Hash = 'wrong' } }
    Assert-Throws { Assert-InstallerIntegrity 'unused' @{ Hash = 'expected'; Algorithm = 'SHA256'; File = 'test' } } 'Checksum mismatch'
    function Get-AuthenticodeSignature { [pscustomobject]@{ Status = 'NotSigned' } }
    Assert-Throws { Assert-InstallerIntegrity 'unused' @{ Hash = $null; File = 'test' } } 'signature'
    function Get-AuthenticodeSignature {
        [pscustomobject]@{ Status = 'Valid'; SignerCertificate = [pscustomobject]@{ Subject = 'Wrong signer' } }
    }
    Assert-Throws { Assert-InstallerIntegrity 'unused' @{ Hash = $null; File = 'test'; Publisher = 'Microsoft Corporation' } } 'Unexpected signer'
}

Test-Case 'successful installer exit still requires actual usable version' {
    Assert-Throws { Confirm-InstalledTool 'git' @(New-TestState) } 'not discoverable'
    function Invoke-SetupNative { 'git version 1.0.0' }
    Assert-Throws { Confirm-InstalledTool 'git' @(New-TestState -Ready 'git') } 'version verification failed'
}

Test-Case 'installer process checks exit status, propagates restart, and never invokes reboot' {
    $script:processCode = 0
    $script:lastProcess = $null
    function Start-Process {
        param($FilePath, $ArgumentList, [switch]$Wait, [switch]$PassThru, $Verb)
        $script:lastProcess = @{ File = $FilePath; Arguments = $ArgumentList; Verb = $Verb }
        [pscustomobject]@{ ExitCode = $script:processCode }
    }
    $spec = @{ Arguments = '/qn /norestart'; Admin = $true }
    Assert-Equal (Invoke-VerifiedInstaller 'C:\fixture with spaces\node.msi' $spec) $false
    Assert-Equal $script:lastProcess.File "$env:SystemRoot\System32\msiexec.exe"
    Assert-Equal $script:lastProcess.Arguments '/i "C:\fixture with spaces\node.msi" /qn /norestart'
    $script:processCode = 3010
    Assert-Equal (Invoke-VerifiedInstaller 'C:\fixture\sdk.exe' $spec) $true
    $script:processCode = 1641
    Assert-Equal (Invoke-VerifiedInstaller 'C:\fixture\sdk.exe' $spec) $true
    $script:processCode = 1603
    Assert-Throws { Invoke-VerifiedInstaller 'C:\fixture\sdk.exe' $spec } 'exit code 1603'
}

Test-Case 'native command exit status is captured correctly' {
    Assert-Throws { Invoke-SetupNative $env:ComSpec @('/d', '/c', 'exit 7') } 'exit 7.*exit 7'
    Assert-Equal (Invoke-SetupNative $env:ComSpec @('/d', '/c', 'echo harmless')) 'harmless'
    Assert-Equal (Invoke-SetupNative $env:ComSpec @('/d', '/c', 'echo harmless-stderr 1>&2 & exit /b 0')).Trim() 'harmless-stderr'
}

Test-Case 'launcher forwards arguments to the same script and preserves exit code' {
    $launcher = Get-Content -LiteralPath (Join-Path $root 'Setup.cmd') -Raw
    Assert-Equal ($launcher.Contains('-File "%~dp0Setup.ps1" %*')) $true
    Assert-Equal ($launcher.Contains('exit /b %setup_exit%')) $true
}

Write-Host "`n$passed passed; $failures failed."
if ($failures) { exit 1 }
