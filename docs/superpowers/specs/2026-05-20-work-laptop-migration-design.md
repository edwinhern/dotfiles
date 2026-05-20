# Work Laptop Migration Design

**Status:** Approved for implementation.

**Issue:** [#39](https://github.com/edwinhern/dotfiles/issues/39)

## Goal

Prepare the dotfiles to set up a work laptop with the current shared toolchain, approved work apps, and a work-specific Dock layout.

## Scope

- Keep `home/dot_config/mise/config.toml.tmpl` unchanged.
- Keep Python in shared mise tools.
- Keep `uv` in personal mise tools.
- Move `mas` to shared Homebrew formulas so personal and work machines can install App Store apps.
- Add work apps without carrying unused ASDF-era tools forward.
- Refactor Dock setup so personal and work layouts share one helper path.
- Add YouTube Music to the Dock only when the Chrome PWA exists.

## Package Design

`home/.chezmoidata/packages.yaml` remains the package source.

Shared Homebrew formulas keep the existing repo tools, including `mise`, `node` support through mise, `dockutil`, `neovim`, `tmux`, `ripgrep`, `fd`, `fzf`, `lazygit`, and OpenCode. Move `mas` from personal formulas to shared formulas.

Shared casks remain unchanged for apps already used across personal and work machines, including `google-chrome`, `ghostty`, `superwhisper`, and `visual-studio-code`.

Work casks add:

- `microsoft-office`
- `microsoft-teams`
- `slack`

`microsoft-office` is used instead of a standalone Outlook cask because the Office cask installs Outlook and conflicts with `microsoft-outlook`.

Work MAS apps add:

- `Be Focused - Pomodoro Timer`, id `973134470`

No work package should add Java, Gradle, Maven, Kafka, Postman, Edge, standalone Python, or standalone `uv`.

## Mise Design

`home/dot_config/mise/config.toml.tmpl` stays as-is:

- Shared tools keep `node`, `pnpm`, and `python`.
- Personal tools keep `biome` and `uv`.
- Work tools keep `redis`.

The work laptop migration should use this existing mise setup instead of adding ASDF compatibility.

## Dock Design

`home/.chezmoitemplates/lib/darwin/defaults.sh` should replace the hard-coded Dock list with small helper functions.

Finder and Trash are not added by the script because macOS keeps them anchored in the Dock. The script only manages the app items between them.

The helper should:

- Remove all existing Dock items once with `dockutil --no-restart --remove all`.
- Add apps in order only when the app path exists.
- Skip missing optional apps without failing.
- Add the Chrome PWA path `$HOME/Applications/Chrome Apps.localized/YouTube Music.app` after Google Chrome only when it exists.
- Restart Dock once after the Dock list is built.

Personal Dock layout keeps the current personal order with Apple Music removed because the YouTube Music Chrome PWA is preferred:

- `/System/Applications/Apps.app`
- `/System/Applications/System Settings.app`
- `/System/Applications/Utilities/Activity Monitor.app`
- `/Applications/Google Chrome.app`
- optional `$HOME/Applications/Chrome Apps.localized/YouTube Music.app`
- `/Applications/Visual Studio Code.app`
- `/Applications/Ghostty.app`
- `/Applications/Discord.app`
- `/System/Applications/Mail.app`
- `/System/Applications/Notes.app`
- `/System/Applications/Reminders.app`
- `/Applications/superwhisper.app`

Work Dock layout starts from the personal layout and replaces Discord and Mail with work communication apps:

- `/System/Applications/Apps.app`
- `/System/Applications/System Settings.app`
- `/System/Applications/Utilities/Activity Monitor.app`
- `/Applications/Google Chrome.app`
- optional `$HOME/Applications/Chrome Apps.localized/YouTube Music.app`
- `/Applications/Visual Studio Code.app`
- `/Applications/Ghostty.app`
- `/Applications/Microsoft Outlook.app`
- `/Applications/Microsoft Teams.app`
- `/Applications/Slack.app`
- `/System/Applications/Notes.app`
- `/System/Applications/Reminders.app`
- `/Applications/superwhisper.app`

If neither personal nor work context is set, the script should use the personal Dock layout because the chezmoi config already defaults unknown non-interactive hosts to personal.

## Testing

- Update `tests/unit/lib/darwin/defaults.bats` to verify Dock setup calls the helper flow and adds expected personal apps.
- Add work-context coverage for Outlook, Teams, and Slack in the Dock helper tests.
- Add package-rendering coverage for `microsoft-office`, `microsoft-teams`, `slack`, shared `mas`, and work MAS id `973134470`.
- Verify shell syntax for rendered defaults scripts.
- Run `mise check`.

## Out of Scope

- Installing the YouTube Music Chrome PWA automatically.
- Adding the unofficial `ytmdesktop-youtube-music` cask.
- Adding ASDF compatibility.
- Adding unused ASDF-era tools such as Java, Gradle, Maven, Kafka, or standalone `uv` for work.
- Changing OpenCode, APM, LazyVim, or tmux configuration.
