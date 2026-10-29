---
name: power-platform-setup
description: Check and, only after explicit user approval, install local Windows prerequisites for Power Platform development with the GitHub Copilot desktop app.
---

# Power Platform setup

Use the reviewed public repository
<https://github.com/danieag/power-platform-setup>.
This skill is an instruction wrapper, not another installer. A repository URL
does not automatically register this skill in the desktop app.

1. Read the repository's `AGENTS.md`, `README.md`, and `Setup.ps1`. Obtain the full
   source if it is not already available locally. Do not run unreviewed downloads.
2. Run `.\Setup.cmd -CheckOnly` in that folder. Add `-IncludeAzureCli` only if the
   requested workflow needs it. This mode is offline and read-only.
   Use the same launcher on x64 and ARM64 Windows 11; it detects native Windows
   architecture even in an emulated terminal. Explain any existing emulated
   tools and optional x64 Azure CLI emulation shown in the plan. Do not replace
   the script with ad hoc architecture-specific installation commands.
3. Summarize the plan and ask the user to explicitly approve installing the
   missing/unsupported tools and accepting the applicable software licenses.
4. After approval, run
   `.\Setup.cmd -Install -Accept -NonInteractive`, with the same approved Azure
   flag if applicable. This still permits Windows UAC to require human action.
5. Respect exit codes, stop on failure/restart requirement, and explain any
   terminal/Copilot restart needed. Report binaries, desktop plugins, and
   authentication separately.
6. If the user also wants Power Platform plugins or Copilot Studio MCP, read
   `skills/power-platform-integrations/SKILL.md` from this repository and use
   its separate approval-gated integration stage. Do not claim that installing
   prerequisites completed plugin/MCP registration.

Never install Copilot CLI/another agent host, enable auto-approval, change
persistent execution policy, blindly run the broad marketplace installer, sign
in, choose an environment, or create cloud resources. The integration skill can
use supported commands on an already available CLI or documented shared MCP
configuration; it must not install another host. Never infer plugin or auth
readiness from the presence of executables.
