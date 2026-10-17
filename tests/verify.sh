#!/usr/bin/env bash
# Verify the setup that install.sh produced. Exits non-zero if any check fails.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"
export TERM="${TERM:-xterm-256color}"
fail=0

check() {
  local name="$1"; shift
  if out="$("$@" 2>&1)"; then
    echo "ok   $name"
  else
    echo "FAIL $name"
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/     /'
    fail=1
  fi
}

# 1. tools
check "nvim >= 0.12" nvim --headless +'lua if vim.fn.has("nvim-0.12") == 0 then os.exit(1) end' +qa
for tool in git rg fd tree-sitter tmux zsh make cc; do
  check "$tool on PATH" command -v "$tool"
done

# 2. configs
check "nvim config"    test -f "$HOME/.config/nvim/init.lua"
check "tmux config"    test -f "$HOME/.tmux.conf"
check "pertmux file"   test -f "$HOME/.kilhak_zsh_functions.zsh"
check "zshrc sources pertmux exactly once" \
  bash -c '[ "$(grep -c "source ~/.kilhak_zsh_functions.zsh" ~/.zshrc)" = 1 ]'

# 3. neovim end to end: clangd, treesitter, telescope, clean startup
nvim_e2e() {
  local tmp out
  tmp="$(mktemp -d)"
  cp "$HERE/t.c" "$HERE/check.lua" "$tmp/"
  out="$(cd "$tmp" && nvim --headless t.c -c "luafile check.lua" 2>&1)"
  rm -rf "$tmp"
  echo "$out"
  local expected
  for expected in \
    "lsp clients: clangd" \
    "treesitter active: true" \
    "fzf ext: true" \
    "diag L6: Use of undeclared identifier 'undefined_var'" \
    "telescope find_files: true" \
    "startup messages: (none)"; do
    grep -qxF "$expected" <<<"$out" || { echo "missing: $expected"; return 1; }
  done
}
check "nvim end-to-end (clangd, treesitter, telescope)" nvim_e2e

# 4. tmux + pertmux
SOCK="verify-$$"
check "tmux mouse bindings" bash -c \
  "tmux -L $SOCK -f ~/.tmux.conf start-server \\; list-keys | grep -q 'mouse on'"
check "pertmux create/list/kill" zsh -c "
  source ~/.kilhak_zsh_functions.zsh || exit 1
  tmux() { command tmux -L $SOCK \"\$@\"; }
  command tmux -L $SOCK new-session -d -s citest || exit 1
  pertmux | grep -q citest || { echo 'session not listed'; exit 1; }
  pertmux kill citest
  pertmux | grep -q 'no sessions' || { echo 'session not killed'; exit 1; }
"
tmux -L "$SOCK" kill-server >/dev/null 2>&1

echo
if [ "$fail" = 0 ]; then echo "all checks passed"; else echo "some checks failed"; fi
exit "$fail"
