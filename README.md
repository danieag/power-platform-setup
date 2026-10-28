# Power Platform setup for Windows

Set up the **local developer tools** used by Microsoft Power Platform skills, in
the right order, with a plan and approval before anything is installed.

You already have the **GitHub Copilot desktop app**. The prerequisite script
does **not** install desktop plugins or register MCP servers; an optional
[second-stage skill](skills/power-platform-integrations/SKILL.md) handles that
separately after approval. Neither stage installs Copilot CLI/another agent host
or creates cloud resources. This is a community bootstrap, not a Microsoft
product or an official installer.

## Short version

**Yes: run the setup file first, then use the integration skill.**

| Step | What you do | What it sets up |
|---|---|---|
| 1. Prerequisites | Download/extract this repository, review the script, then double-click **Setup.cmd**. Approve the displayed plan by typing **INSTALL**. | Git, Node.js/npm, .NET 10 SDK, and PAC CLI, in order. Azure CLI is optional. |
| 2. Integrations | After setup succeeds, restart the Copilot desktop app and ask it to follow the **power-platform-integrations** skill using the prompt below. Approve its separate plan. | Your chosen Power Platform plugins, optional Dataverse, and Copilot Studio MCP registration, using supported setup methods. |
| 3. Sign-in | When ready, complete the required sign-in and choose the intended environment. | Account access and permissions; neither previous step signs you in. |

For **step 2**, paste this into a Copilot desktop chat:

> I have finished running Setup.cmd. Read and follow
> https://github.com/danieag/power-platform-setup/blob/main/skills/power-platform-integrations/SKILL.md.
> Help me install Power Platform Skills, including Dataverse, and register
> Copilot Studio MCP. Show the plan and ask for approval before changing
> anything. Do not sign in or select an environment.

Remove Dataverse or Copilot Studio MCP from the prompt if you do not need them.
The agent can read the skill from the repository; you do not have to install
the skill separately just to ask it to follow those instructions. A link does
not permanently register a skill in the app.

**Setup.cmd does not automatically run the integration skill.** The skill then
performs supported commands/configuration changes for you; you do not normally
need to copy the two installation commands into PowerShell. If a required
capability or permission is unavailable, it explains the remaining desktop
step instead of claiming success.

Already have the prerequisites? Run `.\Setup.cmd -CheckOnly` first. If it reports
that all selected prerequisites are ready, go straight to step 2.

The other skill, [power-platform-setup](skills/power-platform-setup/SKILL.md),
is an **alternative way to guide step 1 through an agent**, not an extra step
you must run after Setup.cmd.

Continue with the [long version](#long-version) for detailed instructions,
supported PCs, security, troubleshooting, and what each stage changes.

## Long version

### Supported PCs and current limitations

> **Initial release status:** syntax and non-installing regression tests are
> automated. A complete installation on a pristine Windows Sandbox has **not**
> been verified. This release targets **x64 Windows 11 / Windows 10 22H2** with
> Windows PowerShell 5.1 or PowerShell 7. ARM64 and 32-bit Windows are rejected
> rather than silently mixing architectures. Use a vendor-supported Windows
> version; Windows 10 support/security servicing is your responsibility.

### Step 1: download, extract, and run Setup.cmd

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
   Continue to [step 2: the integration skill](#step-2-use-the-integration-skill-for-plugins-and-mcp).
   Setup does not start that skill automatically. Sign-in remains separate.

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

The optional [prerequisite skill](skills/power-platform-setup/SKILL.md) contains
these same instructions. The separate
[integration skill](skills/power-platform-integrations/SKILL.md) can then install
approved plugins/register Copilot Studio MCP using supported commands or shared
configuration. Skills instruct the agent to execute the work; they are not just
command lists for the user to copy.

A GitHub URL does not itself install a skill. Load/copy the skills only using a
mechanism supported by your app version, or let the agent read them directly.
No personalized skills, MCP endpoints, or account settings are bundled.

## What gets installed

Compatible tools are left alone. Missing/unsupported tools are handled in this
order; optional Azure CLI comes last:

| Order | Tool | Preserved when | If setup is needed |
|---|---|---|---|
| 1 | Git for Windows | Version 2.40 or newer | Current stable x64 Git installer, current-user program directory |
| 2 | Node.js and npm | Node **22.18+ or 24 LTS**, bundled npm 10+ | Current **24 LTS** x64 MSI, machine-wide |
| 3 | .NET **SDK** | Stable **10.0** SDK files present | Current stable .NET 10 SDK x64 installer, machine-wide |
| 4 | Power Platform CLI (PAC) | Recognized PAC executable version 1.0+ | Current stable `Microsoft.PowerApps.CLI.Tool`, global .NET tool for the current user |
| Optional | Azure CLI | Recognized MSI installation 2.60+ and launcher present | Official x64 Azure CLI MSI, machine-wide |

These are this bootstrap's compatibility baselines, not a guarantee that every
Power Platform plugin supports every accepted version. Node 22.18+ and 24 cover
the current Copilot Studio MCP package's requirements as well as the marketplace's
LTS requirements; this setup deliberately does not treat an arbitrary newer Node
major as compatible. The .NET runtime alone is insufficient. Newer .NET SDK
majors do not replace the required 10.0 SDK. Compatible tools are not automatically
updated to the latest patch; keep them patched using your normal maintenance
process.

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

## Step 2: use the integration skill for plugins and MCP

Use this skill **after step 1 has succeeded** (or check-only has confirmed your
existing prerequisites are ready). This is where plugin installation and MCP
registration happen, not in Setup.cmd.

**Installed binaries do not mean plugins or authentication are configured.**
The readiness summary keeps these three states separate.

Yes, a skill can tell the agent to run terminal commands and make approved
configuration changes for you. You do **not** necessarily need to copy commands
into PowerShell yourself. For example, ask the agent:

> Read skills/power-platform-integrations/SKILL.md in this repository. Set up
> Power Platform Skills, including Dataverse, and Copilot Studio MCP for my
> Copilot desktop app. Show the plan and ask before changing anything.

The [integration skill](skills/power-platform-integrations/SKILL.md) uses these
supported paths:

| Integration | What the skill can do after approval |
|---|---|
| Power Platform plugins | Use an **already available** supported `copilot plugin` command to add the official marketplace and install approved plugins. Verify desktop visibility afterward. If no supported executable is available, use/guide the documented desktop Customize flow; do not install another agent host. |
| Copilot Studio MCP | Use an existing supported `copilot mcp add` command, or safely merge one server entry into the documented user configuration `%USERPROFILE%\.copilot\mcp-config.json`. No CLI installation is required for the file route. |
| Sign-in and environment access | Leave these separate. Registering a server does not authorize sign-in, tenant selection, connector setup, or cloud operations. |

[GitHub's desktop documentation](https://docs.github.com/en/copilot/how-tos/github-copilot-app/customize-github-copilot-app)
confirms that repository/CLI-configured skills and MCP servers are available in
the desktop app. A full plugin can contain additional components; a CLI plugin
listing alone does not prove that all of them work in the desktop app.
The skill must distinguish **configured** from **runtime-verified**, preserve
existing settings, avoid duplicate installs, and stop on real failures.

### Why not simply run the two often-shared commands?

The official
[`microsoft/power-platform-skills`](https://github.com/microsoft/power-platform-skills)
`scripts/install.js --include-dataverse` is a broad installer. It detects
Copilot CLI/Claude Code, can configure both if present, may install PAC, and
enables auto-update. It can be useful when those effects are intended, but it
is not a desktop-only installer. This project's skill prefers scoped
plugin-management commands instead of silently running that broad installer.
Explicitly requesting it still requires review/approval of its effects.

`npx -y @microsoft/copilot-studio-mcp@latest` **launches a server**; by itself it
does not register that server with the app. The skill saves the approved launch
configuration so the app can start it over stdio when needed. The first launch
can download/cache the package; `@latest` permits future version changes.
The [package instructions](https://www.npmjs.com/package/@microsoft/copilot-studio-mcp)
currently require Node 22.18+ and recommend Node 24 LTS. Do not start a standalone
server in a terminal and mistake the running process for a completed integration.

### Desktop controls and verification

The documented desktop path is **Customize**, then marketplace settings beside
the marketplace dropdown to add `microsoft/power-platform-skills`; find and
**Install** the chosen plugins. Examples include `canvas-apps`,
`code-apps-preview`, `model-apps`, and `power-automate`. Dataverse is explicit
opt-in and comes from
[`microsoft/Dataverse-skills`](https://github.com/microsoft/Dataverse-skills);
avoid duplicate installs from two marketplaces. For a custom MCP server,
use **Customize > MCP**. Check **Installed** afterward.

These are documented controls, not a claim that every app version or enterprise
policy exposes the same UI. Refresh/restart the app/session if necessary and
verify that the actual capabilities appear. This repository's tests do **not**
install plugins, register an MCP server, or prove a live desktop integration.

### Step 3: sign in separately

Only after integration setup, intentionally set up sign-in/connections using the correct
account, tenant, and environment. Relevant licensing and permissions remain
separate. Neither setup stage collects tokens, runs `az login` / `pac auth
create`, enables agent auto-approval or Windows features, or writes cloud
resources. Some plugins have additional workflow-specific prerequisites.

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
