# omux

A native macOS terminal for running many [Claude Code](https://claude.com/claude-code) sessions side by side. Sessions are grouped into projects in a sidebar, each one keeps its own Claude conversation across relaunches, and a files panel previews whatever the session is working on.

> **This is a fork** of [onurozcan/omux](https://github.com/onurozcan/omux), which built the app. This fork adds a grid view, broadcast, a command palette, recent conversations in the sidebar and the other changes listed under [What this fork adds](#what-this-fork-adds). Everything else is the original's work.

![omux with a worktree session running three subagents, a session waiting on Allow or Deny, and the Changes tab showing the diff with a review note](docs/screenshot.png)

*Screenshot from the original project; it doesn't show this fork's additions.*

Built with SwiftUI and [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm).

## What this fork adds

Version 0.4.0, on top of the original's 0.3.0:

- **Grid view** (⇧⌘G). Every running session in the project, tiled side by side and sized to keep terminals readable. Click into a tile to type in it; double-click its header to show it alone.
- **Broadcast** (⇧⌘B). Type one prompt and send it to any set of running sessions, for example every session in a project.
- **Command palette** (⌘K). Jump to a session, reopen an old conversation or run any command, including switching themes. Fuzzy matching, ↑/↓ to move, `>` to search only commands.
- **Recent conversations in the sidebar.** Your latest Claude conversations that aren't open, one click from reopening, with Show All for the rest. Conversations are labelled with the title Claude Code gives them instead of the first words of the first prompt.
- **Needs-you triage.** A sidebar banner counts sessions waiting on you; ⌘J jumps to the next one.
- **Menu bar status.** A menu bar icon lists every session with its status and shows a count while sessions need you. Turn it off in Settings › Menu Bar.
- **Session colors you can see.** A session's color shows as a bar on its edge in the sidebar, the grid and the header, instead of only tinting the status dot when Claude has no status.
- **Font zoom** (⌘+ / ⌘− / ⌘0) and four more themes: Catppuccin Mocha, Catppuccin Latte, Tokyo Night and Rosé Pine.
- **`omux` command and `install.sh`.** `omux .` opens the current folder from any terminal.
- **Fix:** buttons at the top of the sidebar, the session header and the right panel's tabs didn't respond to clicks on newer macOS, where the title bar took the click.

See [CHANGELOG.md](CHANGELOG.md) for details.

## Features

- **Projects and sessions.** A project is a folder plus a default command; sessions live under it in the sidebar. Drag to reorder or move sessions between projects, rename them, and give them colors (right-click › Color).
- **Conversations that resume.** Each session that runs `claude` is pinned to its own session id, so quitting and reopening omux continues the same conversation.
- **Live status.** Each session shows whether Claude is working, needs you or is done, and the Dock badge counts sessions waiting on you.
- **Notifications.** When a session you aren't looking at needs you, omux posts a macOS notification; clicking it opens the session. Notifications for finished sessions are optional. Programs can send their own with OSC 9 or OSC 777: set Claude Code's notification channel to `ghostty` (in `/config`) to get its notifications, and its plugins', this way. Turn each kind on or off in Settings › Notifications.
- **Allow or deny from the sidebar.** When Claude asks for a tool permission, Allow and Deny appear under the session and in its header, so you can answer without switching to it.
- **Subagents.** While Claude runs subagents, the selected session lists them in the sidebar with what each one is doing; other sessions show a count. The header's agents button lists them all, and clicking one opens its transcript in the right panel.
- **Worktree sessions** (⌥⌘T). A session can get its own Git branch and folder (`<repo>.worktrees/<branch>` next to the repo), so parallel sessions don't touch each other's files. Turn it on per project to make it the default. Right-click a worktree session to create a pull request, merge it into its base branch or open its folder; closing one asks whether to keep or delete the worktree.
- **Pull request status.** With the [GitHub CLI](https://cli.github.com) installed, a worktree session whose branch has a pull request shows its number and state in the sidebar and header: checks running or failing, changes requested, approved or merged. Click the header chip to see each check and open it on GitHub. The session asks for your attention when checks start failing, a review comes in or the pull request is merged. Once it's merged, the session offers to delete its worktree and branch.
- **Right panel** (⌥⌘F), with three tabs:
  - **Files** (⌥⌘1). Browses the session's folder and previews Markdown, code and text (with optional line wrapping), images, PDFs, audio, video, and anything else Quick Look can show. File paths mentioned in the session's output are listed at the top; ⌘-click a path in the terminal to preview it.
  - **Changes** (⌥⌘2). The session's diff: against the base branch for worktree sessions, uncommitted changes otherwise. Click a line to leave a note, then send all notes to Claude in one message.
  - **Browser** (⌥⌘3). A web view per session that opens the local server the session prints (like `localhost:3000`). The pick button sends an element's HTML, styles and a screenshot to the prompt.
- **Recent conversations** (⇧⌘O). Reopen any Claude Code conversation found in `~/.claude/projects`, from the sidebar's Recent section, the ⇧⌘O list or ⌘K.
- **Usage limits.** The sidebar shows your Claude plan's 5-hour and weekly limits (see [Privacy](#privacy)).
- **Open folders from anywhere.** Finder's right-click "Open in omux" service, dropping a folder on the Dock icon, or `open -a omux <folder>`.
- **Grid view, broadcast, command palette, menu bar status and the `omux` command** (see [above](#what-this-fork-adds)).
- Fifteen themes, terminal font and size.

## Requirements

- macOS 14 or later
- Swift 5.9 or later (Xcode 15+ or the Command Line Tools)
- [Claude Code](https://claude.com/claude-code) installed as `claude` for Claude sessions; plain shell sessions work without it

## Install

```sh
git clone https://github.com/abbasacar/omux && cd omux
./install.sh
omux .
```

`install.sh` runs `build.sh`, then links the `omux` command into `~/.local/bin` (set `OMUX_BIN_DIR` to change it). If omux is already open, quit it (⌘Q) and reopen it to load the new build.

To update later: `git pull && ./install.sh`.

## Build

```sh
./build.sh
open /Applications/omux.app
```

`build.sh` builds a release binary, assembles `build/omux.app`, and then **replaces `/Applications/omux.app`** so the Finder service and Dock entry stay registered. It signs with the first "Apple Development" certificate in your keychain, or ad hoc if there is none.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| New session / new shell / new project | ⌘T / ⇧⌘T / ⇧⌘N |
| New session in a worktree | ⌥⌘T |
| Open folder / recent Claude conversation | ⌘O / ⇧⌘O |
| Close session | ⌘W |
| Rename / edit session | ⌘R / ⌘I |
| Restart session | ⇧⌘R |
| Interrupt (Ctrl-C) | ⇧⌘. |
| Continue Claude conversation | ⇧⌘↩ |
| Command palette / jump to session | ⌘K |
| Next session needing you | ⌘J |
| Grid view | ⇧⌘G |
| Broadcast to sessions | ⇧⌘B |
| Bigger / smaller / actual font size | ⌘+ / ⌘− / ⌘0 |
| Next / previous session | ⇧⌘] / ⇧⌘[ |
| Session 1–9 in the current project | ⌘1 … ⌘9 |
| Right panel / Files / Changes / Browser | ⌥⌘F / ⌥⌘1 / ⌥⌘2 / ⌥⌘3 |

## Privacy

omux has no telemetry and makes two kinds of network request. This fork adds none:

- **Usage limits.** To show your plan limits, omux reads Claude Code's login from the macOS Keychain (the `Claude Code-credentials` item, via `/usr/bin/security`) and sends it to `https://api.anthropic.com/api/oauth/usage`, the same endpoint Claude Code's `/usage` command uses. The token is never written to disk or logged. This endpoint is undocumented and may change or stop working at any time.
- **Pull request status.** If `gh` is installed, omux runs `gh pr view` for each worktree session's branch about once a minute and when you switch back to omux. gh uses its own login; omux never reads or stores your GitHub token.

Local files omux touches:

- `~/Library/Application Support/omux/workspace.json`: your projects and sessions (plus a `.bak` copy).
- `~/.claude/projects`: read to list recent conversations and their titles, to check whether a session's conversation exists, and to show a running session's subagents and their transcripts.
- Worktree sessions run `git` in your repository, and creating a pull request runs `git push` through your login shell. Nothing else is pushed or committed unless you confirm it.
- Elements picked in the browser are saved under your temporary folder (`omux-picks`) so Claude can read them.
- Settings are stored in the standard macOS preferences.

## Disclaimer

omux is an independent project and is not affiliated with or endorsed by Anthropic. This fork is not affiliated with the original author. Claude and Claude Code are trademarks of Anthropic.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for what changed in each version.

## License

[MIT](LICENSE), © onurozcan. This fork's changes are under the same license.
