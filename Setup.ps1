#requires -Version 5.1
<#
.SYNOPSIS
Checks and, only with approval, installs local Power Platform prerequisites.
.EXAMPLE
.\Setup.ps1 -CheckOnly
.EXAMPLE
.\Setup.ps1 -Install -Accept -NonInteractive
#>
[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$Install,
    [switch]$Accept,
    [switch]$NonInteractive,
    [switch]$IncludeAzureCli
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SetupArchitecture {
    if ($env:OS -ne 'Windows_NT') { throw 'This installer supports Windows only.' }
    $architecture = $env:PROCESSOR_ARCHITEW6432
    if (-not $architecture) { $architecture = $env:PROCESSOR_ARCHITECTURE }
    if ($architecture -ne 'AMD64') {
        throw 'This release supports x64 Windows only, not ARM64 or 32-bit Windows.'
    }
    if (-not [Environment]::Is64BitProcess) {
        throw 'Open 64-bit Windows PowerShell or PowerShell and run setup again.'
    }
    $build = Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuildNumber
    if ([int]$build -lt 19045) {
        throw 'Use vendor-supported x64 Windows 11 or Windows 10 22H2 (build 19045 or newer).'
    }
}

function ConvertTo-ToolVersion {
    param([AllowEmptyString()][string]$Text)
    if ($Text -match '(?<!\d)(\d+\.\d+\.\d+)') { return [version]$Matches[1] }
    return $null
}

function Find-SetupExecutable {
    param([string]$Name, [string[]]$Candidates = @())
    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($command) { return $command.Source }
    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }
    return $null
}

function Get-BinaryVersion {
    param([AllowNull()][string]$Path)
    if (-not $Path) { return $null }
    return ConvertTo-ToolVersion (Get-Item -LiteralPath $Path).VersionInfo.ProductVersion
}

function New-ToolState {
    param([string]$Id, [string]$Name, $Version, [bool]$Ready, [string]$Path, [string]$Requirement)
    [pscustomobject]@{
        Id = $Id; Name = $Name; Version = $Version; Ready = $Ready
        Path = $Path; Requirement = $Requirement
    }
}

function Get-SetupState {
    param([switch]$Azure)
    # Read files/registry only: even first-run CLI initialization is excluded.
    $git = Find-SetupExecutable 'git.exe' @(
        "$env:ProgramFiles\Git\cmd\git.exe", "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe")
    $version = Get-BinaryVersion $git
    New-ToolState 'git' 'Git' $version ($null -ne $version -and $version -ge [version]'2.40.0') $git 'Git >= 2.40'

    $node = Find-SetupExecutable 'node.exe' @("$env:ProgramFiles\nodejs\node.exe")
    $version = Get-BinaryVersion $node
    $npmVersion = $null
    if ($node) {
        $nodeRoot = Split-Path -Parent $node
        $npm = Join-Path $nodeRoot 'npm.cmd'
        $npmManifest = Join-Path $nodeRoot 'node_modules\npm\package.json'
        if ((Test-Path -LiteralPath $npm -PathType Leaf) -and (Test-Path -LiteralPath $npmManifest -PathType Leaf)) {
            $npmVersion = ConvertTo-ToolVersion ((Get-Content -LiteralPath $npmManifest -Raw | ConvertFrom-Json).version)
        }
    }
    $nodeSupported = $null -ne $version -and
        (($version.Major -eq 22 -and $version -ge [version]'22.18.0') -or $version.Major -eq 24)
    $ready = $nodeSupported -and
        $null -ne $npmVersion -and $npmVersion -ge [version]'10.0.0'
    New-ToolState 'node' "Node.js / npm ($npmVersion)" $version $ready $node 'Node 22.18+ or 24 LTS with bundled npm >= 10'

    $dotnet = Find-SetupExecutable 'dotnet.exe' @("$env:ProgramFiles\dotnet\dotnet.exe")
    $sdk = $null
    if ($dotnet) {
        $sdkRoot = Join-Path (Split-Path -Parent $dotnet) 'sdk'
        if (Test-Path -LiteralPath $sdkRoot -PathType Container) {
            $sdk = Get-ChildItem -LiteralPath $sdkRoot -Directory |
                Where-Object { $_.Name -match '^10\.0\.\d+$' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'dotnet.dll')) } |
                ForEach-Object { [version]$_.Name } | Sort-Object -Descending | Select-Object -First 1
        }
    }
    New-ToolState 'dotnet' '.NET SDK' $sdk ($null -ne $sdk) $dotnet '.NET 10.0 stable SDK (not just runtime)'

    $pac = Find-SetupExecutable 'pac.exe' @("$env:USERPROFILE\.dotnet\tools\pac.exe")
    $version = Get-BinaryVersion $pac
    New-ToolState 'pac' 'Power Platform CLI' $version ($null -ne $version -and $version -ge [version]'1.0.0') $pac 'PAC >= 1.0; install current stable global .NET tool if missing'

    if ($Azure) {
        $az = Find-SetupExecutable 'az.cmd' @(
            "$env:ProgramFiles\Microsoft SDKs\Azure\CLI2\wbin\az.cmd",
            "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\CLI2\wbin\az.cmd")
        $version = $null
        foreach ($key in @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
            if (Test-Path $key) {
                $entry = Get-ItemProperty $key | Where-Object {
                    $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -eq 'Microsoft Azure CLI'
                } | Select-Object -First 1
                if ($entry -and $entry.PSObject.Properties['DisplayVersion']) {
                    $version = ConvertTo-ToolVersion $entry.DisplayVersion
                    if ($version) { break }
                }
            }
        }
        New-ToolState 'azure' 'Azure CLI' $version ($null -ne $az -and $null -ne $version -and $version -ge [version]'2.60.0') $az 'Azure CLI MSI >= 2.60 (optional)'
    }
}

function Show-SetupState {
    param([object[]]$State)
    Write-Host "`nLocal prerequisite readiness (no tenant access):"
    foreach ($tool in $State) {
        $status = if ($tool.Ready) { 'READY' } else { 'NEEDS SETUP' }
        $detected = if ($tool.Version) { $tool.Version.ToString() } else { 'not detected / unrecognized' }
        Write-Host ("  [{0}] {1}: {2}" -f $status, $tool.Name, $detected)
        Write-Host "    Required: $($tool.Requirement)"
        if ($tool.Path) { Write-Host "    Found: $($tool.Path)" }
    }
    Write-Host "`nDesktop plugins: NOT VERIFIED. Configure separately in the Copilot app; see README."
    Write-Host 'Authentication / environment permissions: NOT CHECKED. Setup never signs you in.'
    Write-Host 'Azure CLI is optional; use -IncludeAzureCli for workflows that require it.'
}

function Update-SetupPath {
    # Preserve inherited process entries, then append newly registered and known locations.
    $paths = @($env:PATH -split ';') +
        @([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';') +
        @([Environment]::GetEnvironmentVariable('Path', 'User') -split ';') +
        @("$env:LOCALAPPDATA\Programs\Git\cmd", "$env:ProgramFiles\Git\cmd",
          "$env:ProgramFiles\nodejs", "$env:ProgramFiles\dotnet",
          "$env:USERPROFILE\.dotnet\tools", "$env:ProgramFiles\Microsoft SDKs\Azure\CLI2\wbin")
    $unique = [System.Collections.Generic.List[string]]::new()
    foreach ($path in $paths) {
        if ($path) {
            $expanded = [Environment]::ExpandEnvironmentVariables($path.Trim())
            if (-not $unique.Contains($expanded)) { $unique.Add($expanded) }
        }
    }
    $env:PATH = $unique -join ';'
}

function Assert-OfficialUrl {
    param([string]$Url)
    $uri = [uri]$Url
    $allowed = @('api.github.com', 'github.com', 'nodejs.org',
        'dotnetcli.blob.core.windows.net', 'builds.dotnet.microsoft.com',
        'download.visualstudio.microsoft.com', 'aka.ms')
    if (-not $uri.IsAbsoluteUri -or $uri.Scheme -ne 'https' -or
        $uri.Host -notin $allowed -or $uri.UserInfo -or -not $uri.IsDefaultPort) {
        throw "Refusing an installer source outside the built-in official HTTPS allowlist: $Url"
    }
}

function Get-OfficialJson {
    param([string]$Url)
    Assert-OfficialUrl $Url
    Invoke-RestMethod -Uri $Url -Headers @{ 'User-Agent' = 'power-platform-setup' } -TimeoutSec 60
}

function Get-InstallerSpec {
    param([ValidateSet('git', 'node', 'dotnet', 'azure')][string]$Id)
    switch ($Id) {
        'git' {
            $release = Get-OfficialJson 'https://api.github.com/repos/git-for-windows/git/releases/latest'
            $asset = @($release.assets | Where-Object { $_.name -match '^Git-[\d.]+-64-bit\.exe$' })
            if ($asset.Count -ne 1 -or $asset[0].digest -notmatch '^sha256:([a-fA-F0-9]{64})$') {
                throw 'Git release metadata has no unique x64 installer with SHA256 digest. No installer was run.'
            }
            $hash = $Matches[1]
            return @{ Url = $asset[0].browser_download_url; File = 'git.exe'; Hash = $hash
                Algorithm = 'SHA256'; Publisher = $null; Admin = $false
                Arguments = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR=`"$env:LOCALAPPDATA\Programs\Git`"" }
        }
        'node' {
            $releases = Get-OfficialJson 'https://nodejs.org/dist/index.json'
            $release = $releases | Where-Object { $_.version -match '^v24\.\d+\.\d+$' -and $_.lts } |
                Select-Object -First 1
            if (-not $release) { throw 'Official metadata contains no stable Node 24 LTS release.' }
            $file = "node-$($release.version)-x64.msi"
            $base = "https://nodejs.org/dist/$($release.version)"
            $checksums = (Invoke-WebRequest -UseBasicParsing -Uri "$base/SHASUMS256.txt" -TimeoutSec 60).Content
            $pattern = '(?m)^([a-fA-F0-9]{64})\s+' + [regex]::Escape($file) + '\s*$'
            if ($checksums -notmatch $pattern) { throw 'No SHA256 checksum found for the Node x64 MSI.' }
            return @{ Url = "$base/$file"; File = 'node.msi'; Hash = $Matches[1]
                Algorithm = 'SHA256'; Publisher = 'OpenJS Foundation|Node\.js Foundation'; Admin = $true
                Arguments = '/qn /norestart' }
        }
        'dotnet' {
            $metadata = Get-OfficialJson 'https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/10.0/releases.json'
            $release = $metadata.releases | Where-Object { $_.sdk.version -eq $metadata.'latest-sdk' } |
                Select-Object -First 1
            $asset = @($release.sdk.files | Where-Object { $_.rid -eq 'win-x64' -and $_.name -like '*.exe' })
            if ($asset.Count -ne 1 -or $asset[0].hash -notmatch '^[a-fA-F0-9]{128}$') {
                throw 'No unique .NET 10 x64 SDK installer with SHA512 checksum was found.'
            }
            return @{ Url = $asset[0].url; File = 'dotnet.exe'; Hash = $asset[0].hash
                Algorithm = 'SHA512'; Publisher = 'Microsoft Corporation'; Admin = $true
                Arguments = '/install /quiet /norestart' }
        }
        'azure' {
            return @{ Url = 'https://aka.ms/installazurecliwindowsx64'; File = 'azure.msi'
                Hash = $null; Algorithm = $null; Publisher = 'Microsoft Corporation'; Admin = $true
                Arguments = '/qn /norestart' }
        }
    }
}

function Assert-InstallerIntegrity {
    param([string]$Path, [hashtable]$Spec)
    if ($Spec.Hash) {
        $actual = (Get-FileHash -LiteralPath $Path -Algorithm $Spec.Algorithm).Hash
        if ($actual -ne $Spec.Hash) { throw "Checksum mismatch for $($Spec.File). No installer was run." }
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid') {
        throw "Invalid/untrusted Authenticode signature on $($Spec.File): $($signature.Status). No installer was run."
    }
    if ($Spec.Publisher -and $signature.SignerCertificate.Subject -notmatch $Spec.Publisher) {
        throw "Unexpected signer on $($Spec.File). No installer was run."
    }
}

function Invoke-VerifiedInstaller {
    param([string]$Path, [hashtable]$Spec)
    $arguments = $Spec.Arguments
    if ([IO.Path]::GetExtension($Path) -eq '.msi') {
        $executable = "$env:SystemRoot\System32\msiexec.exe"
        $arguments = "/i `"$Path`" $arguments"
    } else { $executable = $Path }
    $parameters = @{ FilePath = $executable; ArgumentList = $arguments; Wait = $true; PassThru = $true }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if ($Spec.Admin -and -not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $parameters.Verb = 'RunAs'
        Write-Host 'Windows will ask for administrator approval for this prerequisite only.'
    }
    $process = Start-Process @parameters
    if ($process.ExitCode -notin @(0, 1641, 3010)) {
        throw "Installer failed with exit code $($process.ExitCode). Resolve Windows Installer/UAC or policy issues, then rerun."
    }
    return ($process.ExitCode -in @(1641, 3010))
}

function Invoke-SetupNative {
    param([string]$Path, [string[]]$Arguments)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "The expected executable is missing: $Path"
    }
    # Capture stderr without PowerShell 5.1 turning benign native stderr into a terminating error.
    $ErrorActionPreference = 'Continue'
    $PSNativeCommandUseErrorActionPreference = $false
    # Native processes update the global value, not a local variable with the same name.
    # A sentinel also catches failure to start, while exit 0 with stderr remains success.
    $global:LASTEXITCODE = -1
    $output = & $Path @Arguments 2>&1
    $exitCode = $global:LASTEXITCODE
    if ($exitCode -ne 0) {
        # Do not echo raw CLI output, which can include private feed configuration.
        throw "Command '$([IO.Path]::GetFileName($Path)) $($Arguments -join ' ')' failed (exit $exitCode). Check connectivity, policy, and package sources."
    }
    return ($output -join "`n")
}

function Install-PacTool {
    $state = @(Get-SetupState)
    $dotnet = ($state | Where-Object Id -eq 'dotnet').Path
    if (-not $dotnet) { throw '.NET SDK is not discoverable; open a new terminal and rerun setup.' }
    # Run outside the repository so a project global.json/NuGet.Config cannot select the SDK/feed.
    $working = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $working | Out-Null
    Push-Location $working
    try {
        $config = Join-Path $working 'NuGet.Config'
        @'
<?xml version="1.0" encoding="utf-8"?>
<configuration><packageSources><clear /><add key="nuget.org" value="https://api.nuget.org/v3/index.json" /></packageSources></configuration>
'@ | Set-Content -LiteralPath $config -Encoding UTF8
        $tools = Invoke-SetupNative $dotnet @('tool', 'list', '--global')
        $verb = if ($tools -match '(?im)^microsoft\.powerapps\.cli\.tool\s') { 'update' } else { 'install' }
        Invoke-SetupNative $dotnet @('tool', $verb, '--global', 'Microsoft.PowerApps.CLI.Tool', '--configfile', $config) | Out-Null
    } finally {
        Pop-Location
        Remove-Item -LiteralPath $working -Recurse -Force
    }
}

function Confirm-InstalledTool {
    param([string]$Id, [object[]]$State)
    $tool = $State | Where-Object Id -eq $Id
    if (-not $tool -or -not $tool.Ready) {
        throw "The $Id installer completed, but a compatible installation is not discoverable. Restart the terminal/Copilot app and rerun -CheckOnly. An older PATH entry may be shadowing it."
    }
    switch ($Id) {
        'git' { $output = Invoke-SetupNative $tool.Path @('--version'); $expected = $tool.Version }
        'node' {
            $output = Invoke-SetupNative $tool.Path @('--version'); $expected = $tool.Version
            $npm = Join-Path (Split-Path -Parent $tool.Path) 'npm.cmd'
            $npmVersion = ConvertTo-ToolVersion (Invoke-SetupNative $npm @('--version'))
            if (-not $npmVersion -or $npmVersion -lt [version]'10.0.0') { throw 'npm version verification failed.' }
        }
        'dotnet' {
            $output = Invoke-SetupNative $tool.Path @('--list-sdks')
            if ($output -notmatch '(?m)^10\.0\.\d+\s') { throw '.NET 10 SDK runtime verification failed.' }
            return
        }
        'pac' { $output = Invoke-SetupNative $tool.Path @(); $expected = $tool.Version }
        'azure' {
            $output = Invoke-SetupNative $tool.Path @('version', '--output', 'json')
            $actual = ConvertTo-ToolVersion (($output | ConvertFrom-Json).'azure-cli')
            if (-not $actual -or $actual -lt [version]'2.60.0') { throw 'Azure CLI version verification failed.' }
            return
        }
    }
    if ((ConvertTo-ToolVersion $output) -ne $expected) { throw "$Id executable version verification failed." }
}

function Install-SetupTool {
    param([string]$Id)
    if ($Id -eq 'pac') { Install-PacTool; return $false }
    $spec = Get-InstallerSpec $Id
    Assert-OfficialUrl $spec.Url
    $working = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $working | Out-Null
    try {
        $path = Join-Path $working $spec.File
        Write-Host "Downloading from $($spec.Url)"
        Invoke-WebRequest -UseBasicParsing -Uri $spec.Url -OutFile $path -TimeoutSec 600
        Assert-InstallerIntegrity $path $spec
        return Invoke-VerifiedInstaller $path $spec
    } finally {
        Remove-Item -LiteralPath $working -Recurse -Force
    }
}

function Invoke-Setup {
    param([switch]$CheckOnly, [switch]$Install, [switch]$Accept, [switch]$NonInteractive, [switch]$IncludeAzureCli)
    if (($CheckOnly -and ($Install -or $Accept)) -or ($Accept -and -not $Install)) {
        Write-Host 'Invalid options: use -CheckOnly alone, or -Install [-Accept] [-NonInteractive].'
        return 2
    }
    try {
        Get-SetupArchitecture
        $state = @(Get-SetupState -Azure:$IncludeAzureCli)
        Show-SetupState $state
        $pending = @($state | Where-Object { -not $_.Ready })
        if ($pending.Count -eq 0) {
            Write-Host "`nAll selected prerequisites are ready. Plugins and authentication still need separate verification."
            return 0
        }
        Write-Host "`nPlanned order: $($pending.Name -join ' -> ')"
        if ($CheckOnly) { return 1 }
        if ($NonInteractive -and -not ($Install -and $Accept)) {
            Write-Host 'No changes made. Agent installation requires explicit -Install -Accept -NonInteractive approval.'
            return 2
        }
        if (-not ($Install -and $Accept)) {
            Write-Host 'This will download and run official installers, accept their licenses, and may request UAC.'
            Write-Host 'Git is per-user; Node/.NET/Azure are machine-wide. No cloud login or automatic reboot.'
            $answer = Read-Host 'Type INSTALL to approve this plan (anything else cancels)'
            if ($answer -cne 'INSTALL') { Write-Host 'Cancelled. No changes made.'; return 2 }
        }
        # TLS is changed for this approved process only, never persisted.
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Update-SetupPath
        foreach ($tool in $pending) {
            Write-Host "`nSetting up $($tool.Name)..."
            $restart = Install-SetupTool $tool.Id
            Update-SetupPath
            if ($restart) {
                Write-Host 'Windows reported a restart requirement. Save your work, restart Windows yourself, then rerun setup.'
                Write-Host 'Setup stopped before installing further prerequisites. No reboot was requested by this script.'
                return 3010
            }
            $state = @(Get-SetupState -Azure:$IncludeAzureCli)
            Confirm-InstalledTool $tool.Id $state
        }
        Show-SetupState $state
        Write-Host "`nPrerequisites ready. Restart terminals AND the Copilot desktop app so they inherit the new PATH."
        Write-Host 'Then follow the README for plugins and intentional sign-in. No tenant has been accessed.'
        return 0
    } catch {
        Write-Host "`nSetup failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host 'No later prerequisites were installed. Resolve the cause and rerun -CheckOnly; completed installations are preserved.'
        return 3
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-Setup -CheckOnly:$CheckOnly -Install:$Install -Accept:$Accept -NonInteractive:$NonInteractive -IncludeAzureCli:$IncludeAzureCli)
}
