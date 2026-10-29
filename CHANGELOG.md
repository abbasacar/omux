# Changelog

All notable changes to omux are listed here. Versions follow [Semantic Versioning](https://semver.org).

## [Unreleased]

### Added

- `scripts/demo-screenshot.sh` makes the README screenshot from a demo workspace, with no personal data and no Claude sessions running.

### Fixed

- Window captures from the debug hooks showed terminals with a transparent background.

## [0.4.0] - 2026-10-29

First release of this fork ([abbasacar/omux](https://github.com/abbasacar/omux)). Earlier versions are from [onurozcan/omux](https://github.com/onurozcan/omux).

### Added

- **Grid view** (⇧⌘G): every running session in the project tiled side by side. Tiles keep a readable minimum size and the grid scrolls when more sessions are running than fit. Clicking into a tile selects that session; double-clicking its header shows it alone. With one session running, the grid shows it normally with an Exit Grid button.
- **Broadcast** (⇧⌘B): send one prompt to several running sessions, such as every session in a project.
- **Command palette** (⌘K): the quick switcher also reopens old conversations and runs commands, including switching themes. Fuzzy matching, ↑/↓ to move, `>` to search only commands.
- **Recent conversations in the sidebar**: Claude conversations that aren't open, one click from reopening. Drag the divider above the section to size it, or click its header to collapse it, like the Files browser. Show All (⇧⌘O) searches every conversation.
- **Conversation titles**: conversations are labelled with the title Claude Code gives them instead of the first words of the first prompt, in the sidebar, ⇧⌘O and ⌘K, and as the name of a reopened session.
- **Instructions & Skills** (⇧⌘I), a window that follows the selected project: edit the global and project `CLAUDE.md`; browse, create and edit skills and custom agents (skills synced from claude.ai are shown read-only); and set **omux-only instructions**, globally and per project, which omux passes to every Claude session it starts with `--append-system-prompt`. Changes apply to conversations started afterwards.
- **Next session needing you** (⌘J), and a sidebar banner counting sessions waiting on you.
- **Menu bar status item** listing every session and its state, with a count while sessions need you. It can be turned off in Settings.
- **Font zoom** (⌘= / ⌘− / ⌘0).
- **Themes:** Catppuccin Mocha, Catppuccin Latte, Tokyo Night and Rosé Pine.
- **`omux` command and `install.sh`**: `omux .` opens the current folder in omux.
- For developers: opt-in debug hooks let omux capture its own windows and open test sessions on request, for reviewing the UI without screen-recording permission. See `DebugHooks.swift`.

### Changed

- Status colors (working, needs you, done, error), highlights and usage bars come from the theme, so Dracula, Nord, Catppuccin, Tokyo Night and the others look consistent. Dark, Black, Graphite and Light keep the system colors.
- A session's color shows as a bar and a tint on its row, and the status dot shows only status, so a red session no longer looks like an error. The Color menu shows swatches and checks the current color.
- Stopped sessions show a hollow dot instead of fading, so the sidebar doesn't look disabled after a relaunch.
- ⌘W asks before closing a session that still has something running, and closes the Settings window instead of a session when Settings is in front.
- ⌘R no longer renames a session, so it's left to the terminal; rename from the session's right-click menu or Edit Session (⌘I). ⌘1–9 are labelled "Session n in Project", which is what they always did.
- Icon buttons have bigger click targets, a hover highlight and VoiceOver labels.
- The session header hides its chips and folder before its buttons when the window is narrow.

### Fixed

- Buttons at the top of the sidebar, the session header and the right panel's tabs didn't respond to clicks on newer macOS, where the title bar took the click. They now sit below it.
- Light themes: the terminal's white and bright white were nearly invisible. They're readable grays now, and the needs-you banner and project names are easier to read.
- A new project's name field could lose focus to its terminal before you typed a name.
- A terminal could end up hidden when the view holding it was replaced, for example as grid tiles closed.

## [0.3.0] - 2026-10-29

### Added

- **Pull request status** for worktree sessions, through the GitHub CLI. The sidebar and header show the pull request's number and state (checks running or failing, changes requested, approved, merged), the header chip lists each check, and the session asks for your attention when checks fail, a review arrives or the pull request is merged. Without `gh`, nothing changes. ([#2](https://github.com/onurozcan/omux/pull/2))
- **Clean up merged worktrees.** When a worktree session's pull request is merged, the sidebar, the session menu and the pull request chip offer to close the session and delete its worktree and branch. Closing a merged session says so instead of listing commits that a squash merge leaves behind. ([#3](https://github.com/onurozcan/omux/pull/3))
- **Notifications.** A macOS notification when a session you aren't looking at needs you, such as a tool permission. Clicking it opens the session. Optional notifications when a session finishes, and for notifications programs send with OSC 9 or OSC 777, such as Claude Code's (and its plugins') when its notification channel is `ghostty` or `iterm2`. Each kind can be turned off in Settings › Notifications. ([#4](https://github.com/onurozcan/omux/pull/4))

### Fixed

- The window's close, minimize and full screen buttons were missing on some macOS versions.
- Scanning a session's output for file paths and local URLs read the terminal from a background thread ([#1](https://github.com/onurozcan/omux/issues/1)).

## [0.2.0] - 2026-10-28

### Added

- **Worktree sessions** (⌥⌘T). A session can get its own Git branch and folder, next to the repo in `<repo>.worktrees/<branch>`, so parallel sessions don't touch each other's files. A project setting makes it the default for new sessions. Right-click a worktree session to create a pull request, merge it into its base branch or open its folder. Closing one asks whether to keep or delete the worktree.
- **Tabs in the right panel:** Files (⌥⌘1), Changes (⌥⌘2) and Browser (⌥⌘3).
- **Changes tab.** Shows the session's diff: against the base branch for worktree sessions, uncommitted changes otherwise. Click a line to leave a note, then send all notes to Claude in one message.
- **Browser tab.** A web view per session that opens the local server the session prints, such as `localhost:3000`. The pick button adds an element's HTML, styles and a screenshot to the prompt.
- **Allow and Deny** in the sidebar and the session header when Claude asks for a tool permission, so you can answer without switching sessions.
- **Subagents.** The selected session lists its running subagents and what each one is doing. Other sessions show a count. The header's agents button lists them all, and clicking one opens its live transcript.

### Fixed

- Restarting a session could mark it as stopped when the old terminal's exit arrived after the new one started.

## [0.1.0] - 2026-10-27

First public release.

- Projects and sessions in a sidebar, with drag to reorder, rename and colors.
- Claude conversations that resume after you quit and reopen omux.
- Live status for each session (working, needs you, done) and a Dock badge for sessions waiting on you.
- Files panel that previews Markdown, code and text, images, PDFs, audio, video and anything Quick Look can show.
- Recent Claude conversations (⇧⌘O), Claude plan usage limits in the sidebar, themes, terminal font settings and a quick switcher (⌘K).
- Open folders from Finder's "Open in omux" service, the Dock icon or `open -a omux <folder>`.

[0.4.0]: https://github.com/abbasacar/omux/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/onurozcan/omux/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/onurozcan/omux/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/onurozcan/omux/releases/tag/v0.1.0
