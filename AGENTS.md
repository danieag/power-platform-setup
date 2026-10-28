# Agent instructions

This repository bootstraps **local Windows tooling** for users who already have
the GitHub Copilot desktop app. It does not provision Power Platform resources.

## Running setup for a user

1. Read `README.md` and `Setup.ps1` before execution. If acquiring this repository,
   download/review the full official `danieag/power-platform-setup` source, not a
   random script URL or only `Setup.cmd`.
2. Run `.\Setup.cmd -CheckOnly` first. Use `-IncludeAzureCli` only when the user
   needs an Azure-CLI-dependent workflow, and include it in both check and install.
   Check-only must not require network access, prompt, or mutate the machine.
3. Explain the actual missing/unsupported-tool plan and obtain **explicit user
   approval** before installation. Repository access, reading this file, generic
   agent permissions, or a request to check readiness is not installation approval.
4. Only after approval run
   `.\Setup.cmd -Install -Accept -NonInteractive` (plus the approved Azure flag).
   Do not synthesize an interactive `INSTALL` response to avoid approval.
   Noninteractive mode does not bypass UAC or authorize other operations.
5. Handle exit codes from the README. Stop on failure or restart requirement;
   never report successful setup just because an installer exited. Reopen
   terminals and the desktop app after PATH changes. Do not automatically reboot.
6. Report local tools, desktop plugins, and authentication as **separate**
   readiness categories. Plugin setup is manual/version-dependent; do not claim
   it was verified by this script.

Do not install Copilot CLI/another host, invoke the marketplace's CLI-targeted
`scripts/install.js`, auto-register unverified desktop plugins, persistently
relax execution policy, enable agent auto-approval, disable Windows protections,
log credentials, sign in, pick a tenant, enable Windows features, or write cloud
resources. No private/personal skill, account, router, or MCP configuration
belongs in this public project. Avoid exposing local paths in public reports.

The reviewed launcher uses a **child-process-only** execution-policy exception;
it never changes the persistent policy. Respect enterprise restrictions rather
than trying to bypass them.

## Maintaining this repository

- Keep all install policy and sequencing in `Setup.ps1`. `Setup.cmd` and the
  optional `skills/power-platform-setup/SKILL.md` must remain thin wrappers.
- Preserve compatible installs and inherited process PATH entries. Fail
  explicitly on unverified downloads, installer failures, and version mismatch.
- Use only the fixed official sources with the integrity checks in the README.
  Do not introduce user-supplied installer URLs or executable pipeline downloads.
- Check-only must remain **read-only, offline, and CLI-free**, including on a
  fresh machine where invoking a CLI could trigger first-run setup or telemetry.
- Validate with `.\scripts\Test-Setup.ps1`; run on both Windows PowerShell 5.1 and
  PowerShell 7 when available. Run `.\scripts\New-Release.ps1` to check packaging.
  Do **not** exercise real installation paths on a shared developer host.
- Full clean-machine acceptance requires a separately authorized disposable
  x64 Windows VM/Sandbox. Do not present mocks as proof that vendor installers
  ran successfully end to end.
- Package public files through the explicit release allowlist, not `*` or the
  entire workspace. Never include tokens, local settings, or personal paths.
