# mydevsetup

Neovim (LSP, telescope, treesitter), tmux, and `pertmux` on macOS or Ubuntu.

```sh
git clone https://github.com/kakhil2004/mydevsetup.git && cd mydevsetup
./install.sh          # safe to re-run; existing configs are backed up as *.bak-<date>
./tests/verify.sh     # checks everything installed and works
```

- `configs/` holds the real config files that `install.sh` copies into place
  (`~/.config/nvim/init.lua`, `~/.tmux.conf`, `~/.kilhak_zsh_functions.zsh`).
- `nvim-setup.md` and `pertmux.md` are the long-form notes, including other OSes.
- CI (`.github/workflows/test.yml`) runs install → install again → verify on macOS and a bare Ubuntu 24.04 container on every push.
