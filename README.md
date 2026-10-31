# dotfiles

My macOS setup: zsh with Oh My Zsh, git, Homebrew packages, Claude Code settings with
[ai-devkit](https://github.com/bthanhtung/ai-devkit) skills and memory, and a few tool configs.
One command sets up a new Mac.

## Install

```bash
git clone https://github.com/bthanhtung/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --dry-run   # see what it would do
./install.sh
```

Options: `--no-packages` skips the Brewfile, `--no-claude` skips Claude Code and the ai-devkit skills.

The script is safe to re-run. Existing files are moved to `~/.dotfiles-backup/<timestamp>/`
before anything is replaced, and finished steps are skipped.

## What it sets up

| Step | Details |
| --- | --- |
| Homebrew | installs Homebrew if missing, then everything in `Brewfile` (CLI tools, apps, VS Code extensions) |
| Shell | Oh My Zsh with `zsh-autosuggestions` and `zsh-syntax-highlighting`, nvm with the latest Node.js LTS |
| Dotfiles | symlinks `zsh/`, `git/`, `herdr/`, `ai-devkit/` configs into `~` |
| Claude Code | installs Claude Code, writes `~/.claude/settings.json` (claude-hud status line), installs the ai-devkit built-in skills globally and the `ai-devkit-memory` MCP server |

```
zsh/          .zshrc, .zshenv, .bash_profile
git/          .gitconfig, .gitignore_global
claude/       settings.json template (copied, because Claude Code writes machine state into it)
herdr/        ~/.config/herdr/config.toml
ai-devkit/    ~/.ai-devkit/.ai-devkit.json (registers the bthanhtung/ai-devkit skill registry)
Brewfile      Homebrew formulae, casks, VS Code extensions
install.sh    the installer
```

## Secrets and machine-specific settings

Nothing secret lives in this repo. Put tokens, work email, and per-machine tweaks in files that
the configs load but git ignores:

- `~/.zshrc.local`, sourced at the end of `.zshrc`
- `~/.gitconfig.local`, included by `.gitconfig`

## Updating

Edit the files here (the symlinks make `~/.zshrc` and friends point at them), then commit. To refresh
the package list: `brew bundle dump --force --file Brewfile`.

## Credits

Started as a fork of [codeaholicguy/dotfiles](https://github.com/codeaholicguy/dotfiles); its vim and
tmux setup is still in this repo's git history.
