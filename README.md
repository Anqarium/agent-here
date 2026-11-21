# agent-here

Adds four entries to the **new Windows 11 context menu** (the short one, not only
"Show more options"):

- **Open in Claude Code CLI**: opens `claude` (the Claude Code CLI) in Windows Terminal, in the
  folder you clicked.
- **Open in Claude Code Desktop**: starts a new Claude Code session on that folder in the Claude
  desktop app.
- **Open in Antigravity CLI**: opens `agy` (the Antigravity CLI) in Windows Terminal, in the
  folder you clicked.
- **Open in Antigravity Desktop**: opens the folder you clicked in the Antigravity app.

The Claude entries show up when `claude` or the Claude desktop app is installed; the Antigravity
entries when `agy` or the Antigravity app (`%LOCALAPPDATA%\Programs\antigravity`) is installed.
They show up when you right-click a folder and when you right-click empty space inside one.
The titles follow the Windows display language: Turkish on a Turkish UI, English otherwise.

> Unofficial. Not affiliated with or endorsed by Anthropic or Google.

## How it behaves

**Open in Claude Code CLI** uses Windows Terminal's **default profile**, so the tab gets that
profile's icon, colours and title, and `claude` starts *inside* the profile's shell:

| Default profile | What runs |
| --- | --- |
| PowerShell 7 / Windows PowerShell | `pwsh -NoExit -Command "& 'claude.exe'"` |
| Command Prompt | `cmd /k "claude.exe"` |
| anything else (WSL, Git Bash, …) | `claude.exe` directly, with the profile's look |

Your shell profile loads, and when `claude` exits you are left in the shell in that folder.
The default profile is read on every click, so changing it in Windows Terminal takes effect
at once. Without Windows Terminal, `claude` opens in the default console.

**Open in Claude Code Desktop** opens `claude://code/new?folder=<path>`. The desktop app asks for
confirmation every time a folder comes from another app; that is the app's own safety
check, and there is no setting to turn it off. The entry is hidden when the desktop app is
not installed, and the terminal entry is hidden when `claude` is not found.

### Recent sessions

When the clicked folder has Claude Code sessions, both entries open a submenu: **New session**,
a separator, then the five most recent sessions of that folder (newest first, labelled with the
session's title and time). Both entries list the same sessions.

- Terminal: resuming runs `claude --resume <id>` in the folder.
- Desktop: resuming opens `claude://resume?session=<id>`.

The sessions are read from `%USERPROFILE%\.claude\projects\`. Sessions that Claude started on
its own (scheduled tasks, sessions spawned by another session) are left out. Without sessions in the folder,
the entries behave as before: one click starts a new session.

### Optional start prompt

The repo ships no prompt of its own. If you create `%LOCALAPPDATA%\AgentHere\start-prompt.txt`
with some text (for example a slash command or a short instruction), the submenu's **New session**
starts with that text as the first message. It applies only where the submenu exists, that is in
folders that already have sessions; in a folder without sessions the click stays a plain new
session. Without the file nothing changes. The text is sent at once, as `claude "<text>"`. This is
for the terminal entry only: the desktop app never sends the text of a link (it only fills a
draft) and does not recognize a slash command there, so the desktop entry is unchanged. Quotes,
`;`, `%` and line breaks in the file are replaced by spaces. `uninstall.ps1` deletes that folder,
the file included.

## How it works

A small C++ COM DLL (`src/AgentHere.cpp`) implements `IExplorerCommand`. Each command is
registered by its own **sparse package** (`package/AppxManifest.template.xml`). This is the
same mechanism Windows Terminal uses for "Open in Terminal". The DLL runs in a `dllhost.exe`
surrogate, not inside Explorer.

Each command is a separate package so Windows does not fold them into one submenu, and
each can be moved in or out of the main menu on its own under **Settings → Personalization
→ Context menu → App extensions** (on builds that have that page).

**Open in Antigravity CLI** also opens a submenu (**New session** and the five most recent
conversations opened in that folder, newest first) once the folder has agy conversations;
resuming runs `agy --conversation <id>`. They are read from
`%USERPROFILE%\.gemini\antigravity-cli\conversation_summaries.db` with the system's
`winsqlite3.dll`. **Open in Antigravity Desktop** (the app) has no submenu and always opens the folder
directly; neither Antigravity entry uses the start prompt. `agy.exe` has no icon of its own, so the CLI entry
shows the Antigravity IDE's dark icon when that is installed, and the app's icon otherwise.

## Requirements

- Windows 11 with **Developer Mode on**, because the packages are registered unsigned.
- Visual Studio 2022 with the C++ tools, and the Windows 11 SDK
  (`winget install Microsoft.WindowsSDK.10.0.26100`).
- Claude Code CLI (`%USERPROFILE%\.local\bin\claude.exe` or on `PATH`), and optionally the
  Claude desktop app (the MSIX package or the per-user setup in `%LOCALAPPDATA%\AnthropicClaude`).
- Optionally the Antigravity CLI (`%LOCALAPPDATA%\agy\bin\agy.exe` or on `PATH`) and the
  Antigravity app (`%LOCALAPPDATA%\Programs\antigravity\Antigravity.exe`).

## Install

Run from PowerShell 7 in the repo folder:

```powershell
.\build.ps1      # builds build\AgentHere.dll and build\AgentHereStub.exe
.\install.ps1    # copies them to %LOCALAPPDATA%\AgentHere and registers the packages
```

Run both again to update. To remove everything:

```powershell
.\uninstall.ps1
```

If an entry does not appear right away, check the **App extensions** settings page, or sign
out and back in.

## License

[MIT](LICENSE)
