# CLAUDE.md

Windows 11 context menu shell extension (`IExplorerCommand`) adding "Open in Claude Code",
"Open in Claude Desktop", "Open in Antigravity CLI" and "Open in Antigravity". It was called
`claude-here` until the Antigravity entries made the name too narrow. Behaviour and install steps
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
.\install.ps1    # copies to %LOCALAPPDATA%\AgentHere, registers the four sparse packages
.\uninstall.ps1  # removes the packages and the install folder
```

The maintainer has authorised Claude, in every session of this repo, to run `.\install.ps1` itself
whenever a change needs installing (after `.\build.ps1`); do not ask them to run it.

There are no automated tests. The COM side was checked with a throwaway probe that calls
`CoCreateInstance` + `GetTitle`/`GetIcon`/`GetState`/`Invoke` on every CLSID; the menu itself
can only be checked by hand. Without installing, a probe can `LoadLibrary` `build\AgentHere.dll`,
call its `DllGetClassObject`, then `GetState` on a folder and `EnumSubCommands` to list the
session submenu. Installed copies are `%LOCALAPPDATA%\AgentHere\{Terminal,Desktop,AntigravityCli,Antigravity}\AgentHere.dll`.

## Notes

- Packages are unsigned and registered with `Add-AppxPackage -Register -ExternalLocation`,
  which needs Developer Mode. Without it, signing would need makeappx + a certificate
  trusted in TrustedPeople (admin).
- Register from `%LOCALAPPDATA%\AgentHere`, never from the repo: the loaded DLL gets locked.
  `install.ps1` first stops the `dllhost` processes holding it.
- The commands are deliberately separate packages (`AgentHere.Terminal`, `AgentHere.Desktop`,
  `AgentHere.AntigravityCli`, `AgentHere.Antigravity`): Windows may group several verbs of one
  package into a submenu.
- Antigravity entries: `agy` (`%LOCALAPPDATA%\agy\bin\agy.exe`) runs in Windows Terminal like the
  Claude terminal entry, without resume or start prompt; the app entry runs
  `%LOCALAPPDATA%\Programs\antigravity\Antigravity.exe "<folder>"`. The CLI entry also has the
  session submenu (`ScanAgySessions`): rows of `~\.gemini\antigravity-cli\conversation_summaries.db`
  read with the system's `winsqlite3.dll`, matched by decoding `workspace_uris` (file:/// URIs) and
  comparing with the folder; sub-agent rows (`parent_conversation_id`) and never-used ones
  (`last_modified_time` 0001-01-01) are hidden; many older rows have an empty `title`, then only the
  time shows; resume is `agy --conversation <id>`. The `datetime` column has numeric affinity, so a
  bare `> '2000'` compares wrongly: use `substr(...) >= '2000'`. The app entry has no submenu (no
  known way to resume a conversation there). `agy.exe` has no icon resource, so `install.ps1` takes
  the CLI entry's icon from `Antigravity.exe` (`IconExe`). The app path is the install that
  registers the `antigravity://` protocol (2.26.0); `Programs\Antigravity IDE` (2.7.0, with its
  own Explorer command DLL) is a second install that is not used.
- The CLSIDs live in both `src/AgentHere.cpp` and `install.ps1`; change them together.
- Menu icons: `GetIcon` returns `icon.ico` next to the DLL, falling back to the exe's icon 0.
  `install.ps1` generates it from each exe, cropped to the visible area, because the CLI's
  own icon has about 2 px of padding at 32 px and the desktop app's has none (they looked
  different in size). No icon art is committed to the repo.
- Package logos (Settings → Context menu → App extensions): Windows resolves `Logo` against the
  external location (`%LOCALAPPDATA%\AgentHere\<cmd>\Assets\`), not the manifest's `package\`
  folder, so `install.ps1` writes them to both; with only `package\Assets` Settings showed a
  placeholder. Check with WinRT `PackageManager.FindPackageForUser(...).Logo` from Windows
  PowerShell 5.1 (pwsh 7 cannot load WinRT types).
- Re-registering the same CLSIDs under new package names (the claude-here → agent-here rename)
  left the already running Explorer without the entries; `Stop-Process explorer` does not work
  from Claude's shell, so the maintainer restarts Explorer (Task Manager) or signs out.
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
  Terminal only: the desktop `code/new` handler reads `q` or `prompt` (read from app.asar), but it
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
