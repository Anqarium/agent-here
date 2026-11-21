# CLAUDE.md

Windows 11 context menu shell extension (`IExplorerCommand`) adding "Open in Claude Code CLI",
"Open in Claude Code Desktop" and "Open in Antigravity CLI". It was called `claude-here` until the
Antigravity entry made the name too narrow. Behaviour and install steps
are in `README.md`.

## Language

The repository is public: code, comments, docs and commit messages (Conventional Commits)
are in English. This overrides the user's global preference for Turkish docs and commits.
Exception: the Turkish menu titles in `src/AgentHere.cpp` and package names in
`install.ps1`. The first commits are in Turkish; history is not rewritten. Replies to the
user in chat stay in Turkish.

## Commands

```powershell
.\build.ps1      # MSVC via vcvars64, outputs to build\
.\install.ps1    # copies to %LOCALAPPDATA%\AgentHere, registers the three sparse packages
.\uninstall.ps1  # removes the packages and the install folder
```

The maintainer has authorised Claude, in every session of this repo, to run `.\install.ps1` itself
whenever a change needs installing (after `.\build.ps1`); do not ask them to run it.

There are no automated tests. The COM side was checked with a throwaway probe that calls
`CoCreateInstance` + `GetTitle`/`GetIcon`/`GetState`/`Invoke` on every CLSID; the menu itself
can only be checked by hand. Without installing, a probe can `LoadLibrary` `build\AgentHere.dll`,
call its `DllGetClassObject`, then `GetState` on a folder and `EnumSubCommands` to list the
session submenu. Installed copies are `%LOCALAPPDATA%\AgentHere\{Terminal,Desktop,AntigravityCli}\AgentHere.dll`.

## Notes

- Packages are unsigned and registered with `Add-AppxPackage -Register -ExternalLocation`,
  which needs Developer Mode. Without it, signing would need makeappx + a certificate
  trusted in TrustedPeople (admin).
- Register from `%LOCALAPPDATA%\AgentHere`, never from the repo: the loaded DLL gets locked.
  `install.ps1` first stops the `dllhost` processes holding it.
- The commands are deliberately separate packages (`AgentHere.Terminal`, `AgentHere.Desktop`,
  `AgentHere.AntigravityCli`): Windows may group several verbs of one package into a submenu.
- Antigravity CLI entry: `agy` (`%LOCALAPPDATA%\agy\bin\agy.exe`) runs in Windows Terminal like the
  Claude terminal entry; its submenu's New sends the start prompt with `agy -i` (`--prompt-interactive`:
  sends it and stays open). agy finds global skills only in `~/.gemini/config/skills/<name>/SKILL.md`
  and does not follow a junction there (the maintainer's `brifing` is a real folder whose `SKILL.md`
  is a hard link to `~/.agents/skills/brifing/SKILL.md`; `agy -p "/brifing"` loaded it). It has the session submenu (`ScanAgySessions`): rows of `~\.gemini\antigravity-cli\conversation_summaries.db`
  read with the system's `winsqlite3.dll`, matched by decoding `workspace_uris` (file:/// URIs) and
  comparing with the folder; sub-agent rows (`parent_conversation_id`) and never-used ones
  (`last_modified_time` 0001-01-01) are hidden; many older rows have an empty `title`, then only the
  time shows; resume is `agy --conversation <id>`. The `datetime` column has numeric affinity, so a
  bare `> '2000'` compares wrongly: use `substr(...) >= '2000'`. `agy.exe` has no icon resource, so
  `install.ps1` takes the entry's icon from `Programs\Antigravity IDE\Antigravity IDE.exe` (the "A"
  on a dark grid tile, like the Claude CLI's tile), falling back to
  `Programs\antigravity\Antigravity.exe` (`IconExe` / `Find-AgyIcon`). No CLI-specific icon exists
  online either. The IDE's tile has square corners, so the entry's `Round = 0.22` clips it to the
  Claude CLI tile's radius.
- An "Open in Antigravity Desktop" entry existed and was dropped (maintainer's decision): the
  Antigravity app (`Programs\antigravity`, 2.26+) is an agent-manager hub, not an editor. Its main
  process ignores a folder argument (only `antigravity://` links and `--ssh-host=` are read) and its
  UI, served by `resources\bin\language_server.exe` on a local port, routes deep links only for
  plugins/customizations, `teleport/ai_studio` and sign-in, so nothing opens a folder from outside.
  `install.ps1` and `uninstall.ps1` still remove the old `AgentHere.Antigravity` package.
- The CLSIDs live in both `src/AgentHere.cpp` and `install.ps1`; change them together.
- Menu icons: `GetIcon` returns `icon.ico` next to the DLL, falling back to the exe's icon 0.
  `install.ps1` generates it from each exe, cropped to the visible area, because the CLI's
  own icon has about 2 px of padding at 32 px and the desktop app's has none (they looked
  different in size). The package logos go through the same crop (`Get-VisibleRect`,
  `New-IconSquare`); uncropped, Claude Code looked smaller than Claude Desktop in Settings.
  No icon art is committed to the repo.
- Package logos (Settings → Context menu → App extensions): Windows resolves `Logo` against the
  external location (`%LOCALAPPDATA%\AgentHere\<cmd>\Assets\`), not the manifest's `package\`
  folder, so `install.ps1` writes them to both; with only `package\Assets` Settings showed a
  placeholder. Check with WinRT `PackageManager.FindPackageForUser(...).Logo` from Windows
  PowerShell 5.1 (pwsh 7 cannot load WinRT types).
- Re-registering the same CLSIDs under new package names (the claude-here → agent-here rename)
  left the already running Explorer without the entries; `Stop-Process explorer` does not work
  from Claude's shell, so the maintainer restarts Explorer (Task Manager) or signs out.
- Menu order: Windows sorts these entries by title, not by registration order or package name.
  The titles end in "CLI" / "Desktop" so each CLI entry sorts above its desktop entry (the
  maintainer's naming); keep that in mind before renaming a title.
- Language: the menu title uses `GetUserDefaultUILanguage` (the display language Explorer
  uses); the package name uses `Get-UICulture` at install time. Windows Terminal follows the
  preferred-languages list instead, so its own entry can be in a different language.
- Terminal entry: reads Windows Terminal's `settings.json` on every click (JSONC: comments
  and trailing commas are stripped, then `Windows.Data.Json`), passes `defaultProfile` with
  `-p` and runs claude inside the profile's shell. If the profile already carries a command
  (`-Command`, `/c`, …), claude runs directly instead.
- Start prompt: the repo deliberately ships no prompt text and no language logic (the maintainer's
  own flow is a personal `/brifing` skill, not for everyone). `StartPrompt()` reads the user's
  `%LOCALAPPDATA%\AgentHere\start-prompt.txt`; when it has text, the submenu's "New session"
  (`Role::New`, which exists only for folders with earlier sessions) sends it. The root click of a
  folder without sessions stays plain (nothing to summarize yet, and a prompt costs a model turn);
  a separate "New session + prompt" item was tried and dropped. The terminal passes it as claude's first argument so
  the model answers at once (a hook can only add context, never make it speak). The text crosses three
  quoting layers (wt, the shell, claude), so `StartPrompt()` turns quotes, `;`, `%` and control
  characters into spaces. pwsh gets it in single quotes inside `-Command "..."`; cmd needs the whole
  `/k` line wrapped in one extra pair of quotes (it strips the first and last quote when there are
  more than two). A slash command works as the prompt in the terminal (`/brifing` loaded the skill).
  Terminal entries only (Claude and agy): the desktop `code/new` handler reads `q` or `prompt` (read from app.asar), but it
  only fills a draft and the app offers no auto-send parameter (the allowed extras are `folder`,
  `file`, `environment`, `runner_pool`); a slash command shows as plain text. The workspace-trust
  dialog is not the cause (`trusted=true` in the log). So the desktop entry sends no prompt.
- Desktop app detection: the MSIX package `Claude_pzs8sxrjxfjjc` first, then the per-user
  Squirrel setup's launcher `%LOCALAPPDATA%\AnthropicClaude\claude.exe` (a reinstall can switch
  from one to the other; without a match `GetState` hides the entry). Change both in
  `src/AgentHere.cpp` and `install.ps1`, and re-run `install.ps1` so the icon is regenerated.
- Desktop entry: `claude://code/new?folder=<encodeURIComponent>` is the format the desktop
  app's own `ccd` alias produces (read from its app.asar). The app adds `src=external` and
  always asks for confirmation; this cannot be bypassed. Its "Trust this workspace?" answer
  is stored in the CLI's `~/.claude.json` (`projects[path].hasTrustDialogAccepted`).
- Recent sessions submenu: transcripts are `%USERPROFILE%\.claude\projects\<dir>\<uuid>.jsonl`,
  where `<dir>` is the folder path with every non-alphanumeric character replaced by `-` (checked
  on ASCII paths only). `cwd` comes from the first 512 KB. The title is `customTitle` (`/rename`,
  `claude -n`, a hook's `sessionTitle`) if present, else `aiTitle`, as in Claude Code's `/resume`;
  both lines are re-appended during a session, so the newest one is taken from the last 512 KB,
  falling back to the first 512 KB. Sessions whose first prompt has
  `promptSource: "system"` (coordinator relays, scheduled tasks) are hidden: across 110 local
  transcripts only those had it; typed ones carry `typed`, `queued`, `sdk` or nothing. The submenu needs
  `GetState` to see the clicked folder first, because `GetFlags` and `EnumSubCommands` get no items.
  `ECF_HASSPLITBUTTON` was tried and dropped: the new menu shows the arrow but never invokes the
  root, so "New session" stays inside the submenu.
- Desktop resume: `claude://resume?session=<uuid>` (host `resume`, read from app.asar). It imports
  the CLI transcript into a new desktop session with the history; the CLI session is untouched.
