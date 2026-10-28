---
name: power-platform-integrations
description: After explicit approval, set up Microsoft Power Platform plugins including optional Dataverse and register the Copilot Studio MCP server for the GitHub Copilot desktop app, using supported shared configuration without installing another agent host.
---

# Power Platform integrations

Use this skill when the user asks to install Power Platform Skills/plugins,
include Dataverse, add Copilot Studio MCP, or finish the integration stage after
the local prerequisites. Perform the approved work with tools; do not merely
give the user commands to copy unless a genuine permission or capability
blocker prevents execution.

This is **stage two**, not a second prerequisite installer. Read the current
`README.md` and `AGENTS.md` in
<https://github.com/danieag/power-platform-setup> first. Do not execute anything
when the user only asks for an explanation or readiness check.

## 1. Inspect, explain, approve

- Run the repository's `.\Setup.cmd -CheckOnly` first. Do not treat its exit 1
  (missing/unsupported tools) as permission to install them; use the prerequisite
  skill only after approval. Keep this check offline and read-only.
- Copilot Studio MCP currently requires **Node 22.18+ or 24 LTS**. Read the
  [current package instructions](https://www.npmjs.com/package/@microsoft/copilot-studio-mcp)
  before configuring it; a future release can change requirements.
- Confirm which integrations the user wants: selected Power Platform plugins,
  Dataverse (explicit opt-in), Copilot Studio MCP, or the combination.
  Explain downloads, user configuration changes, and later app reload/sign-in.
  Obtain approval for the actual plan, separately from prerequisite approval.
- Determine the configuration scope and discover an **already available**
  `copilot` executable with `Get-Command -CommandType Application`. Do not
  install Copilot CLI, start a different agent host, search private app internals
  for undocumented binaries, or modify PATH to make one appear.
- Inspect only the relevant existing plugin/server definitions. Do not print,
  upload, commit, or log full user configuration: other entries can hold tokens.
  Preserve unrelated definitions and organization policies. Do not start a
  server, authenticate, or query a tenant to check whether a definition exists.

GitHub documents that skills and MCP servers configured for repositories or
Copilot CLI are available in the desktop app. This does **not** make every
CLI-installed plugin component desktop-compatible. Verify desktop visibility
separately before calling the integration ready.

## 2. Install Power Platform plugins

The official marketplace is
<https://github.com/microsoft/power-platform-skills>.

If an existing supported `copilot` executable is available, use its documented
plugin-management commands from PowerShell after approval. These are terminal
subcommands, not `/plugin` text pasted into a shell:

```powershell
copilot plugin list
copilot plugin marketplace add microsoft/power-platform-skills
copilot plugin install canvas-apps@power-platform-skills
copilot plugin list
```

`canvas-apps` is an example, **not** an instruction to install it for everyone.
Use the current official marketplace manifest to resolve only approved plugin
names. Other examples include `code-apps-preview`, `model-apps`, and
`power-automate`. Add `dataverse@power-platform-skills` only when approved;
check whether Dataverse is already installed from the external
`microsoft/Dataverse-skills` marketplace to avoid duplicate capabilities.

Read command help when the installed version differs from the documented
interface. Check every exit code. Skip an existing matching marketplace/plugin
after inspecting it; an error containing "already" is not sufficient proof of
success. Do not uninstall, overwrite a different source, or force-update a
working plugin without approval. Do not enable auto-approval or auto-update as
an unrequested side effect.

The user's often-seen command:

```powershell
iwr https://raw.githubusercontent.com/microsoft/power-platform-skills/main/scripts/install.js -OutFile install.js
node install.js --include-dataverse
```

is a **different, broad installer**: it detects Copilot CLI/Claude Code, can
configure both if present, installs the marketplace's selected plugin set, may
install PAC, and enables auto-update. It is not a desktop-only installer.
Do not run it blindly or delete a pre-existing `install.js`. Prefer scoped
commands above so the approved host, plugins, and settings are explicit.
If the user specifically requests that broad installer, explain its current
effects, inspect the downloaded code in a new temporary directory, and get
approval for those effects; do not silently substitute it for this plan.

If no supported plugin-management executable is available, **do not install
another host as a workaround**. Use documented desktop controls, or guide the
user through them if UI automation is unavailable:

1. **Customize** > marketplace settings beside the marketplace dropdown:
   add `microsoft/power-platform-skills`.
2. Find each approved plugin in **Customize**, then **Install**.
3. Confirm it appears under **Installed**.

Do not copy only skill folders and claim a full plugin was installed: plugins
can also contain agents, hooks, and MCP configuration.

## 3. Register Copilot Studio MCP

The package is <https://www.npmjs.com/package/@microsoft/copilot-studio-mcp>.
Its launch command is `npx -y @microsoft/copilot-studio-mcp@latest`.
The MCP host starts it over stdio when needed. Running that command alone in a
terminal is **not** registration, and can leave an unused long-running process.

If the existing `copilot` command supports the documented MCP subcommands:

```powershell
copilot mcp add copilot-studio -- npx -y @microsoft/copilot-studio-mcp@latest
```

This is a user-scope configuration change. Inspect for an existing equivalent
server, including a differently named or plugin-provided one, first. Skip an
exact match; ask before replacing a different server or duplicating it.
Do not invoke `/mcp auth` in a desktop-hosted conversation.

**No CLI executable is required for the documented configuration-file route.**
With explicit approval for user scope, merge this single server definition
into `%USERPROFILE%\.copilot\mcp-config.json`:

```json
{
  "mcpServers": {
    "copilot-studio": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@microsoft/copilot-studio-mcp@latest"],
      "tools": ["*"]
    }
  }
}
```

This is the desired **entry shape**, not permission to replace the whole file.
If editing:

- Stop on invalid/unsupported JSON; never replace it with an empty default.
- Read the live file, preserve all unrelated keys/entries and existing access
  controls, and keep a protected local recovery copy if a file already exists.
  Never print that copy or include it in a repository or release ZIP.
- Re-read before writing; if another process changed the file, merge from the
  new live content rather than overwriting it. Write atomically and confirm the
  target entry without exposing other configuration.
- If safe merging or permissions cannot be established, stop and use the app's
  **Customize > MCP > add a custom server** flow instead. Report the exact
  remaining step; do not claim registration succeeded.

Use **user scope** for this general developer setup. A requested project-only
setup needs that app version's documented repository-customization flow; do
not invent a repository config schema or turn a local setting into a committed
change without explicit approval.

`tools: ["*"]` exposes the server's advertised tools; it does **not** authorize
executing them or enable agent auto-approval. Using `@latest` means the first
launch can download/cache the current package and future launches can receive
new versions. Explain that behavior before approval; an organization can instead
approve a specific published version after checking its requirements.

## 4. Verify registration, then hand off sign-in

- Confirm only the intended marketplace/plugins and MCP definition changed.
  Treat package download, registration, tool discovery, authentication, and
  environment access as distinct states.
- Refresh/restart the desktop session if necessary. Check **Customize >
  Installed** and the actual available skills/tools. A CLI plugin listing or
  JSON entry alone proves configuration, not desktop runtime readiness.
- Launching the configured MCP server may require user trust/permission. Do
  not run cloud tools as a smoke test, initiate sign-in, select an environment,
  or access tenant data under installation approval.
- When the user is ready to authenticate, follow the desktop app's sign-in
  action for this server. Account/environment/connector setup is separate and
  may require additional permissions. Never collect credentials or log tokens.
- Report completed actions and precise blockers. If visibility/launch has not
  been confirmed, say **configured, not runtime-verified** rather than "ready".
  Do not retry an uncertain installation/write without inspecting its result.

## Verified documentation

Recheck these contracts when the app or package changes:

- [Desktop customization and shared skill/MCP configuration](https://docs.github.com/en/copilot/how-tos/github-copilot-app/customize-github-copilot-app)
- [MCP terminal commands and configuration-file format](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers)
- [Power Platform marketplace and installer source](https://github.com/microsoft/power-platform-skills)
- [Copilot Studio MCP package](https://www.npmjs.com/package/@microsoft/copilot-studio-mcp)
