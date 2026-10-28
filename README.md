# Power Platform setup for Windows

Set up the **local developer tools** used by Microsoft Power Platform skills, in
the right order, with a plan and approval before anything is installed.

You already have the **GitHub Copilot desktop app**. This project does **not**
install Copilot CLI, another agent host, desktop plugins, or cloud resources.
It is a community bootstrap, not a Microsoft product or an official installer.

> **Initial release status:** syntax and non-installing regression tests are
> automated. A complete installation on a pristine Windows Sandbox has **not**
> been verified. This release targets **x64 Windows 11 / Windows 10 22H2** with
> Windows PowerShell 5.1 or PowerShell 7. ARM64 and 32-bit Windows are rejected
> rather than silently mixing architectures. Use a vendor-supported Windows
> version; Windows 10 support/security servicing is your responsibility.

## Start here: download, extract, double-click

1. On [this repository](https://github.com/danieag/power-platform-setup), choose
   **Code > Download ZIP**. Extract **all** files to a folder you can find.
   Do not run `Setup.cmd` from inside the ZIP or download just the launcher.
2. Read this page and review `Setup.ps1`, then double-click **Setup.cmd**.
   Start as your normal user, **not** "Run as administrator".
3. Setup checks local files and shows what is missing. Type **INSTALL** only
   if you approve the displayed plan and the vendors' software licenses.
   Anything else cancels without downloading or installing anything.
4. Approve Windows administrator prompts only for the expected Node.js,
   Microsoft .NET SDK, or optional Microsoft Azure CLI installer.
   If setup requests a restart, save your work, restart yourself, and run it again.
5. After success, fully quit and reopen the Copilot desktop app and terminals.
   Then configure your chosen plugins and sign-in separately (below).

Internet access is needed **only after installation approval**. Setup does not
need `winget`, Git, npm, or .NET to start. This is important in Windows Sandbox,
where `winget` is often absent. Enabling or creating Sandbox is outside scope;
its filesystem is normally discarded when you close it.

The launcher and an agent both use the same `Setup.ps1`; there is no second
installation implementation.

### Check without changing anything

Open PowerShell in the extracted folder:

```powershell
.\Setup.cmd -CheckOnly
```

Or, when your execution policy permits local scripts:

```powershell
.\Setup.ps1 -CheckOnly
```

Check-only reads local executable version metadata, npm's package manifest,
SDK directories, and (if requested) Azure CLI's Windows uninstall registration.
It **does not execute any CLI**, download files, write diagnostics, alter PATH,
change Windows features/policies, sign in, or contact a tenant. It reports
**local installation readiness**, not a guarantee that every installed binary,
plugin, network connection, or account works. Output includes local paths;
review/redact these before posting it publicly.

### Let an agent use the repository

Open the extracted repository in the Copilot desktop app, or point an agent to
this public repository and ask it to download/review it first:

> Read AGENTS.md in https://github.com/danieag/power-platform-setup. Run the
> check-only setup, explain the plan, and ask me before installing anything.
> Do not install Copilot CLI, configure auto-approval, or sign in to a tenant.

After the user has explicitly approved the actual plan, an agent can use:

```powershell
.\Setup.cmd -Install -Accept -NonInteractive
```

`-Accept` accepts the selected installers and their licenses; it is **not**
authorization to change plugin settings, sign in, or access an environment.
`-NonInteractive` suppresses the script's approval prompt, **not Windows UAC**.
An unattended process without a usable UAC session will fail rather than bypass
Windows security. Agents must not add `-Accept` without user approval.

For workflows that need Azure CLI, opt in explicitly on **both** the check and
install commands:

```powershell
.\Setup.cmd -CheckOnly -IncludeAzureCli
.\Setup.cmd -Install -Accept -NonInteractive -IncludeAzureCli
```

The optional [thin skill](skills/power-platform-setup/SKILL.md) contains these
same instructions. A GitHub URL does not itself install a skill. Load/copy that
skill only using a mechanism supported by your app version, or let the agent
read it directly. No personalized skills, MCP endpoints, or account settings
are bundled.

## What gets installed

Compatible tools are left alone. Missing/unsupported tools are handled in this
order; optional Azure CLI comes last:

| Order | Tool | Preserved when | If setup is needed |
|---|---|---|---|
| 1 | Git for Windows | Version 2.40 or newer | Current stable x64 Git installer, current-user program directory |
| 2 | Node.js and npm | Node **22 or 24 LTS**, bundled npm 10+ | Current **24 LTS** x64 MSI, machine-wide |
| 3 | .NET **SDK** | Stable **10.0** SDK files present | Current stable .NET 10 SDK x64 installer, machine-wide |
| 4 | Power Platform CLI (PAC) | Recognized PAC executable version 1.0+ | Current stable `Microsoft.PowerApps.CLI.Tool`, global .NET tool for the current user |
| Optional | Azure CLI | Recognized MSI installation 2.60+ and launcher present | Official x64 Azure CLI MSI, machine-wide |

These are this bootstrap's compatibility baselines, not a guarantee that every
Power Platform plugin supports every accepted version. Node 22 and 24 cover
the current official marketplace's LTS requirements; this setup deliberately
does not treat an arbitrary newer Node major as compatible. The .NET runtime
alone is insufficient. Newer .NET SDK majors do not replace the required 10.0
SDK. Compatible tools are not automatically updated to the latest patch;
keep them patched using your normal maintenance process.

Nonstandard/portable installations, version-manager shims, stale PATH entries,
unknown file versions, and non-MSI Azure CLI installs may need manual repair.
The first executable on PATH is authoritative; setup does not delete or
reorder competing installations or overwrite version-manager configuration.
Installing Node 24 over a newer MSI may require manually removing that
unsupported major first. Setup stops if it cannot verify the result.
For upgrades of older machine-wide Git, use the vendor installer manually if
the new per-user copy is shadowed by the old PATH entry.

### Downloads, verification, and privilege

No arbitrary installer URL parameter exists. Direct official downloads are the
normal path, **not** an unverified fallback when `winget` fails:

| Tool | Built-in source and integrity check |
|---|---|
| Git | [`git-for-windows/git` official GitHub release](https://github.com/git-for-windows/git/releases/latest), GitHub asset SHA256 digest **and** valid Windows Authenticode signature |
| Node | [nodejs.org distribution metadata](https://nodejs.org/dist/index.json), matching official `SHASUMS256.txt` **and** valid OpenJS/Node.js Foundation Authenticode signature |
| .NET | [Microsoft .NET 10 release metadata](https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/10.0/releases.json), matching SHA512 **and** valid Microsoft Authenticode signature |
| PAC | [Microsoft's documented .NET global tool](https://learn.microsoft.com/en-us/power-platform/developer/howto/install-cli-net-tool), from NuGet.org using an isolated package-source configuration |
| Azure | [Microsoft's x64 MSI link](https://aka.ms/installazurecliwindowsx64), valid Microsoft Authenticode signature (no separate published hash used here) |

If metadata, checksums, certificate trust, or signer verification fails, setup
stops. It never falls back to running an unverified file. Official HTTPS
endpoints can redirect to their distribution CDNs; payload verification still
applies. Metadata and installers are resolved at approval time, so new installs
receive the then-current stable patch, not a permanently pinned version.
"Deterministic" means one ordered, fixed-policy workflow, not byte-identical
packages forever.

Downloaded installers and the temporary NuGet configuration are removed after
use. No diagnostic file or credential log is created by this project; approved
vendor installers/CLIs may maintain their own normal caches, telemetry, and logs.
No installer is run during this repository's tests.

Git is directed to `%LOCALAPPDATA%\Programs\Git`; when run unelevated its
registration is per-user. An already-elevated session can cause Git's vendor
installer to write machine registration, so start unelevated. PAC is installed
for the **invoking user** under `%USERPROFILE%\.dotnet\tools`.
Only installers requiring machine-wide access request UAC. Do not start the
entire setup with a different administrator account.
The script refreshes **only its process PATH**, retaining inherited entries,
and does not rewrite your persistent PATH itself (vendor installers do their
normal registration). Existing Copilot/terminal processes must be restarted.

### PowerShell and downloaded-file security

`Setup.cmd` starts Windows PowerShell with `-NoProfile -ExecutionPolicy Bypass`
**for that child process only** so a downloaded, unsigned script can run after
you review it. It does not call `Set-ExecutionPolicy` or change persistent policy.
This exception is deliberate, not proof that downloaded code is safe.
Do not run files you do not trust.

SmartScreen, Mark of the Web, enterprise Group Policy, AppLocker, WDAC, proxy
policy, and certificate restrictions can still block setup. Follow your
organization's approved process; do not disable those protections. For example,
an organization's signed-script requirement needs an approved/signed copy,
not a machine-wide policy relaxation. No automatic reboot is requested.

## Finish in the Copilot desktop app: plugins, then sign-in

**Installed binaries do not mean plugins or authentication are configured.**
The readiness summary keeps these three states separate.

The official marketplace is
[`microsoft/power-platform-skills`](https://github.com/microsoft/power-platform-skills).
Its published `scripts/install.js` currently detects **Copilot CLI / Claude
Code**. This repository does **not** run it or install another host to make
desktop plugin registration appear successful.

In the desktop app, open **Customize** and look for the plugin/marketplace
installation controls available in **your version**. If it supports adding a
marketplace by repository, use `microsoft/power-platform-skills`, then install
only the plugins needed for your work, such as `canvas-apps`,
`code-apps-preview`, `model-apps`, or `power-automate`. The optional `dataverse`
entry comes from the external official
[`microsoft/Dataverse-skills`](https://github.com/microsoft/Dataverse-skills)
repository; avoid duplicate installs from two marketplaces.

**The exact desktop marketplace UI and registration flow are not verified
across app versions.** Do not paste CLI `/plugin` commands into a terminal or
assume a repository URL installs plugins. If the controls are absent, consult
your app's current documentation/admin instead of installing Copilot CLI as a
workaround. Confirm the chosen plugin appears installed and its capabilities
are available in the desktop app.

Only afterward, intentionally set up the plugin's connections and sign-in using
the correct account, tenant, and environment. Relevant licensing, roles, and
environment access are separate requirements. Setup does not inspect or store
tokens, choose an environment, run `az login` / `pac auth create`, enable agent
auto-approval, enable Windows features, or write cloud resources.
Some plugins have additional workflow-specific prerequisites; this bootstrap
does not promise every feature is usable immediately.

**PAC limitation:** Microsoft's .NET tool does not include `pac data` or certain
`pac package` commands (`deploy`, `show`), even on Windows.
If you need these, use the
[official Windows MSI alternative](https://learn.microsoft.com/en-us/power-platform/developer/howto/install-cli-msi)
intentionally and manage overlapping PATH entries. See the
[installation-method comparison](https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction).
PAC prints its version when called as **`pac`**, not a presumed `pac --version`.
Use **`npm.cmd`** in PowerShell to avoid the unrelated `npm.ps1` policy issue.

## Exit codes and troubleshooting

| Code | Meaning / next action |
|---|---|
| `0` | Selected local prerequisites detected/verified. Plugins/auth are still separate. |
| `1` | Check-only found missing or unsupported prerequisites. This is an expected readiness result. |
| `2` | Cancelled, invalid options, or noninteractive install lacks explicit opt-in. Nothing installed. |
| `3` | Unsupported host, detection error, download, trust, installer, or version-verification failure. Stop and fix the reported cause. |
| `3010` | Installer requested/reported a restart. Chain stopped; restart Windows yourself, then rerun. |

The launcher forwards this code. Policy/PowerShell failures before the script
starts may return PowerShell's own nonzero code instead.

| Symptom | Safe next step |
|---|---|
| No `winget` in Sandbox | No action needed; this setup uses official direct installers. |
| Permission/UAC denied or installer code `1603` | Review admin/policy requirements; ask your administrator. Do not elevate the whole agent. |
| Installer code `1618` | Another Windows installation is running; let it finish, then rerun. |
| Installer succeeded but tool is still missing/old | Restart the Copilot app and terminal; inspect the reported path for a shadowing old install. Do not repeatedly install blindly. |
| TLS/proxy/certificate/download error or GitHub API rate limit | Fix access to the listed official endpoints, wait for a rate-limit reset if applicable, then rerun. Do not disable certificate checks or substitute random downloads. |
| .NET SDK exists but a project uses another SDK | Inspect that project's `global.json`; setup does not change it. |
| Azure reported unrecognized despite a working portable CLI | This release recognizes MSI metadata only. Use/repair the official MSI or manage that tool outside setup. |
| PAC installation fails | Check NuGet.org access, Windows policy, and whether an existing PAC shim conflicts. Source configuration is isolated, not taken from your project. |

It is safe to rerun: completed compatible tools are skipped; a failure stops
the chain and does not roll back earlier successful vendor installations.
Remove software through Windows Installed apps or its own package manager;
there is no broad cleanup/uninstall command.

## Validate and create a shareable ZIP

For contributors, from a checkout or **Code > Download ZIP** source folder
(the smaller packaged runtime ZIP intentionally omits contributor scripts):

```powershell
.\scripts\Test-Setup.ps1
.\scripts\New-Release.ps1
```

The dependency-free tests parse every PowerShell script and mock all
installation paths: approval, ordered plan, skip/rerun, failures, restart,
version verification, source/integrity gates, and PATH preservation. A real
local inventory test uses only reads. CI runs on Windows PowerShell 5.1 and
PowerShell 7. CI does **not** install tools or validate a pristine Sandbox
installation. Maintainers should perform that manual acceptance test before
claiming full end-to-end coverage.

Packaging writes only `dist\power-platform-setup-windows.zip` and its `.sha256`
file. An explicit allowlist includes the launcher, installer, README, agent
instructions, license, and skill; it excludes repository history, test outputs,
personal configuration, secrets, and installed packages. The ZIP is also
uploaded as a CI artifact. An artifact checksum detects accidental changes;
it is not a code-signing certificate or proof of publisher identity.

## License

[MIT](LICENSE) for this project's code. Vendor tools have their own licenses
and support policies. Review downloaded code before running it.
