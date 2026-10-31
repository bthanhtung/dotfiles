#!/usr/bin/env bash
# Sets up a new Mac with these dotfiles. Safe to re-run: existing files are backed up, finished steps are skipped.
#
#   ./install.sh               everything
#   ./install.sh --dry-run     print what would happen, change nothing
#   ./install.sh --no-packages skip Homebrew packages (Brewfile)
#   ./install.sh --no-claude   skip installing Claude Code and ai-devkit skills
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
PACKAGES=1
CLAUDE=1

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-packages) PACKAGES=0 ;;
    --no-claude) CLAUDE=0 ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
run() {
  if (( DRY_RUN )); then printf '    would run: %s\n' "$*"; else "$@"; fi
}

backup() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    run mkdir -p "$BACKUP"
    run mv "$target" "$BACKUP/"
    printf '    backed up %s\n' "$target"
  fi
}

# Symlink $DOTFILES/$1 to $2, backing up whatever is there unless it already points here.
link() {
  local source="$DOTFILES/$1" target="$2"
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    printf '    ok %s\n' "$target"
    return
  fi
  run mkdir -p "$(dirname "$target")"
  backup "$target"
  run ln -s "$source" "$target"
  printf '    linked %s -> %s\n' "$target" "$source"
}

if [[ "$(uname -s)" != Darwin ]]; then
  echo "These dotfiles target macOS." >&2
  exit 1
fi

say "Homebrew"
if ! command -v brew >/dev/null 2>&1 && [[ ! -x /opt/homebrew/bin/brew ]]; then
  run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
if (( PACKAGES )); then
  run brew bundle --file "$DOTFILES/Brewfile" || echo "    some Brewfile entries failed; re-run later (VS Code extensions need the 'code' command)"
fi

say "Oh My Zsh and plugins"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  run env RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  if [[ ! -d "$ZSH_CUSTOM/plugins/$plugin" ]]; then
    run git clone --depth 1 "https://github.com/zsh-users/$plugin" "$ZSH_CUSTOM/plugins/$plugin"
  else
    printf '    ok %s\n' "$plugin"
  fi
done

say "nvm and Node.js LTS"
if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
  run git clone --depth 1 https://github.com/nvm-sh/nvm.git "$HOME/.nvm"
fi
if (( ! DRY_RUN )) && [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  set +u
  export NVM_DIR="$HOME/.nvm"
  . "$NVM_DIR/nvm.sh"
  nvm ls --no-colors default >/dev/null 2>&1 || { nvm install --lts && nvm alias default 'lts/*'; }
  set -u
fi

say "Dotfiles"
link zsh/zshrc "$HOME/.zshrc"
link zsh/zshenv "$HOME/.zshenv"
link zsh/bash_profile "$HOME/.bash_profile"
link git/gitconfig "$HOME/.gitconfig"
link git/gitignore_global "$HOME/.gitignore_global"
link herdr/config.toml "$HOME/.config/herdr/config.toml"
link ai-devkit/ai-devkit.json "$HOME/.ai-devkit/.ai-devkit.json"

say "Claude Code settings"
# Copied, not linked: Claude Code writes machine-specific state into settings.json.
settings="$HOME/.claude/settings.json"
node_bin="$(command -v node || echo node)"
if (( DRY_RUN )); then
  printf '    would write %s (node: %s)\n' "$settings" "$node_bin"
else
  mkdir -p "$HOME/.claude"
  rendered="$(sed -e "s|__HOME__|$HOME|g" -e "s|__NODE__|$node_bin|g" "$DOTFILES/claude/settings.json")"
  if [[ -f "$settings" ]] && [[ "$(cat "$settings")" == "$rendered" ]]; then
    printf '    ok %s\n' "$settings"
  else
    backup "$settings"
    printf '%s\n' "$rendered" >"$settings"
    printf '    wrote %s\n' "$settings"
  fi
fi

if (( CLAUDE )); then
  say "Claude Code and ai-devkit skills"
  if ! command -v claude >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/claude" ]]; then
    run bash -c "curl -fsSL https://claude.ai/install.sh | bash"
  else
    printf '    ok claude\n'
  fi
  run npx -y ai-devkit@latest skill add --built-in --global --env claude || echo "    ai-devkit skills failed; re-run later"
  if command -v claude >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/claude" ]]; then
    claude_bin="$(command -v claude || echo "$HOME/.local/bin/claude")"
    if "$claude_bin" mcp get ai-devkit-memory >/dev/null 2>&1; then
      printf '    ok ai-devkit-memory MCP\n'
    else
      run "$claude_bin" mcp add --scope user ai-devkit-memory -- npx -y @ai-devkit/memory
    fi
  fi
fi

say "Done"
[[ -d "$BACKUP" ]] && echo "Previous files are in $BACKUP"
if [[ ! -f "$HOME/.claude/plugins/claude-hud/statusline.mjs" ]]; then
  echo "Status line: open Claude Code once and run /claude-hud:setup to create it."
fi
echo "Put machine-specific settings and secrets in ~/.zshrc.local and ~/.gitconfig.local (never committed)."
echo "Open a new terminal to load the shell config."
