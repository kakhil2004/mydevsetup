#!/usr/bin/env bash
# Install my dev setup (neovim, tmux, pertmux) on macOS or Ubuntu.
# Safe to re-run: installed tools are skipped, existing configs are backed up.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$HOME/.local/bin" "$HOME/.local/opt"
export PATH="$HOME/.local/bin:$PATH"

log() { printf '\n==> %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

nvim_ok() {
  have nvim && nvim --headless +'lua if vim.fn.has("nvim-0.12") == 0 then os.exit(1) end' +qa >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------

install_macos() {
  if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install || true
    echo "Finish the Xcode Command Line Tools install, then re-run this script." >&2
    exit 1
  fi
  if ! have brew; then
    echo "Homebrew is required: https://brew.sh" >&2
    exit 1
  fi
  # only install what's missing (brew install would also upgrade what's present)
  local formula missing=()
  for formula in neovim ripgrep fd tree-sitter-cli tmux; do
    brew list --formula "$formula" >/dev/null 2>&1 || missing+=("$formula")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    log "Installing with Homebrew: ${missing[*]}"
    brew install "${missing[@]}"
  fi
}

install_ubuntu() {
  local sudo=""
  [ "$(id -u)" -ne 0 ] && sudo="sudo"

  log "Installing apt packages"
  $sudo apt-get update
  DEBIAN_FRONTEND=noninteractive $sudo apt-get install -y \
    git curl ca-certificates unzip tar gzip build-essential ripgrep fd-find tmux zsh
  # Ubuntu names the fd binary fdfind
  have fd || ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"

  local arch tsarch
  case "$(uname -m)" in
    x86_64) arch=x86_64; tsarch=x64 ;;
    aarch64 | arm64) arch=arm64; tsarch=arm64 ;;
    *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
  esac

  # apt's neovim is older than 0.12, so use the official tarball
  if ! nvim_ok; then
    log "Installing neovim (official tarball)"
    curl -fsSL -o /tmp/nvim.tar.gz \
      "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$arch.tar.gz"
    rm -rf "$HOME/.local/opt/nvim-linux-$arch"
    tar -xzf /tmp/nvim.tar.gz -C "$HOME/.local/opt"
    ln -sf "$HOME/.local/opt/nvim-linux-$arch/bin/nvim" "$HOME/.local/bin/nvim"
    rm -f /tmp/nvim.tar.gz
  fi

  # nvim-treesitter needs the tree-sitter CLI (not the npm one)
  if ! have tree-sitter; then
    log "Installing tree-sitter CLI"
    curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-$tsarch.gz" \
      | gunzip > "$HOME/.local/bin/tree-sitter"
    chmod +x "$HOME/.local/bin/tree-sitter"
  fi
}

case "$(uname -s)" in
  Darwin) install_macos ;;
  Linux)
    if [ -r /etc/os-release ] && grep -qiE '^(ID|ID_LIKE)=.*(ubuntu|debian)' /etc/os-release; then
      install_ubuntu
    else
      echo "unsupported Linux distro (only Ubuntu/Debian is handled)" >&2
      exit 1
    fi
    ;;
  *) echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

nvim_ok || { echo "neovim >= 0.12 is required but not available" >&2; exit 1; }
for tool in git rg fd tree-sitter tmux zsh; do
  have "$tool" || { echo "missing after install: $tool" >&2; exit 1; }
done

# ---------------------------------------------------------------------------
# Configs
# ---------------------------------------------------------------------------

# Copy src to dest, backing up dest first if it exists and differs.
put() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && ! cmp -s "$src" "$dest"; then
    mv "$dest" "$dest.bak-$STAMP"
    echo "backed up $dest -> $dest.bak-$STAMP"
  fi
  cp "$src" "$dest"
}

log "Writing configs"
put "$REPO/configs/nvim/init.lua" "$HOME/.config/nvim/init.lua"
put "$REPO/configs/tmux.conf" "$HOME/.tmux.conf"
put "$REPO/configs/pertmux.zsh" "$HOME/.kilhak_zsh_functions.zsh"

SOURCE_LINE='[ -f ~/.kilhak_zsh_functions.zsh ] && source ~/.kilhak_zsh_functions.zsh'
touch "$HOME/.zshrc"
if ! grep -qF "$SOURCE_LINE" "$HOME/.zshrc"; then
  printf '\n# kilhak zsh functions (pertmux)\n%s\n' "$SOURCE_LINE" >> "$HOME/.zshrc"
fi
if ! grep -qF '.local/bin' "$HOME/.zshrc"; then
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.zshrc"
fi

# ---------------------------------------------------------------------------
# Neovim plugins, parsers, language servers
# ---------------------------------------------------------------------------

log "Installing neovim plugins"
nvim --headless +qa

log "Compiling tree-sitter parsers"
nvim --headless +'lua require("nvim-treesitter").install({"c","cpp","python","bash","lua","vim","vimdoc","markdown","markdown_inline","json","yaml","make"}):wait(300000)' +qa

if [ ! -x "$HOME/.local/share/nvim/mason/bin/clangd" ]; then
  log "Installing clangd via Mason"
  nvim --headless +'MasonInstall clangd' +qa
fi

log "Done. Open a new terminal (or: source ~/.zshrc) to get pertmux."
case "${SHELL:-}" in
  */zsh) ;;
  *) echo "Your login shell isn't zsh; pertmux needs it. Switch with: chsh -s \"\$(command -v zsh)\"" ;;
esac
