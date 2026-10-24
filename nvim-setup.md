# Neovim setup: install guide for an agent

This guide reproduces a beginner-friendly Neovim setup. It has fuzzy finding, LSP for C/C++ with clangd, autocomplete, Tree-sitter highlighting, auto-pairs, a status bar, a VS Code-style file tree sidebar, a git changed-files picker that works across multi-repo folders (e.g. Brazil workspaces), a terminal launcher, bright relative line numbers, and Space-leader shortcuts.

It was built and verified on **Amazon Linux 2 (x86_64, glibc 2.26)** with Neovim 0.12.5. Instructions for other OSes use each platform's standard install method but **haven't been tested**. Verify every step with the checks in section 5.

Versions used in the original build: Neovim 0.12.5, clangd 23.1.0 (via Mason), tree-sitter CLI 0.27.1, ripgrep 15.2.0, fd 10.5.0.

---

## 0. Rules for the agent

1. **Back up any existing config** before writing a new one. Move `~/.config/nvim`, `~/.local/share/nvim`, `~/.local/state/nvim` and `~/.cache/nvim` to `*.bak-<date>` (on Windows, `%LOCALAPPDATA%\nvim` and `%LOCALAPPDATA%\nvim-data`). Don't delete anything.
2. Prefer user-local installs into `~/.local/bin` and `~/.local/opt` when the system package manager would need sudo or ships an old Neovim. Make sure `~/.local/bin` is on `PATH`.
3. **Neovim must be ≥ 0.12.** The config uses the built-in plugin manager `vim.pack` and `vim.lsp.config`/`vim.lsp.enable`, so it won't run on 0.11 or older.
4. After each install, run `<tool> --version`. A prebuilt binary that fails with `GLIBC_x.yy not found` means the system glibc is too old. Use the old-glibc path in section 2.6.

---

## 1. Requirements

| Tool | Minimum | Why |
|---|---|---|
| neovim | 0.12 | editor; `vim.pack` plugin manager |
| git | any | `vim.pack` clones plugins; `Space c` and the file tree's git status call it |
| curl, tar, unzip | any | Mason downloads and extracts language servers; nvim-treesitter downloads grammars |
| C compiler (gcc/clang/cl/zig) | any | compiles Tree-sitter parsers |
| make | any | builds telescope-fzf-native (optional; telescope works without it) |
| tree-sitter CLI | 0.26.1 | required by nvim-treesitter `main` branch. **Don't install it from npm.** |
| ripgrep (`rg`) | any | telescope live grep |
| fd | any | faster telescope file finding (optional) |

---

## 2. Install the tools for each OS

### 2.1 macOS (Homebrew)
```sh
xcode-select --install            # C compiler + make (skip if already installed)
brew install neovim ripgrep fd git
brew install tree-sitter-cli      # if not found, try: brew install tree-sitter
```

### 2.2 Debian / Ubuntu
```sh
sudo apt update
sudo apt install -y git curl unzip tar build-essential ripgrep fd-find
mkdir -p ~/.local/bin && ln -sf "$(command -v fdfind)" ~/.local/bin/fd   # Debian names it fdfind
```
apt's `neovim` is usually older than 0.12, so use the official tarball (2.7). For the tree-sitter CLI, try the official binary (2.7). If it fails with a GLIBC error (it needed glibc ≥ 2.35 as of v0.27.1), build it with cargo (2.6).

### 2.3 Fedora / RHEL 9+ / Amazon Linux 2023
```sh
sudo dnf install -y git curl unzip tar gcc make ripgrep fd-find neovim tree-sitter-cli
nvim --version | head -1   # must be >= 0.12; otherwise use the tarball (2.7)
tree-sitter --version      # must be >= 0.26.1; otherwise use cargo (2.6)
```

### 2.4 Arch
```sh
sudo pacman -S --needed neovim git curl unzip base-devel ripgrep fd tree-sitter-cli
```

### 2.5 Windows (winget, untested)
```powershell
winget install Neovim.Neovim Git.Git BurntSushi.ripgrep.MSVC sharkdp.fd zig.zig
# tree-sitter CLI: download tree-sitter-windows-x64.gz from
#   https://github.com/tree-sitter/tree-sitter/releases/latest, unzip it, rename it to tree-sitter.exe, and put it on PATH
#   (or: cargo install --locked tree-sitter-cli)
```
Without `make`, the fzf-native build is skipped automatically and telescope still works. The config path is `%LOCALAPPDATA%\nvim\init.lua`.

### 2.6 Old-glibc Linux (Amazon Linux 2, CentOS/RHEL 7): what was actually done
The official Neovim and tree-sitter binaries need a newer glibc than these systems have.

```sh
mkdir -p ~/.local/bin ~/.local/opt
ARCH=x86_64   # or arm64

# Neovim: the neovim/neovim-releases repo publishes builds that work on old glibc
curl -fsSL -o /tmp/nvim.tar.gz \
  https://github.com/neovim/neovim-releases/releases/latest/download/nvim-linux-$ARCH.tar.gz
tar -xzf /tmp/nvim.tar.gz -C ~/.local/opt
ln -sf ~/.local/opt/nvim-linux-$ARCH/bin/nvim ~/.local/bin/nvim

# ripgrep + fd: static musl builds have no glibc dependency.
# Resolve the latest tag from the redirect, since api.github.com may rate-limit (403).
latest() { curl -sSI "https://github.com/$1/releases/latest" | grep -i '^location' | sed 's#.*/tag/##' | tr -d '\r'; }
RG=$(latest BurntSushi/ripgrep)   # e.g. 15.2.0
FD=$(latest sharkdp/fd)           # e.g. v10.5.0
cd "$(mktemp -d)"
curl -fsSLO "https://github.com/BurntSushi/ripgrep/releases/download/$RG/ripgrep-$RG-x86_64-unknown-linux-musl.tar.gz"
curl -fsSLO "https://github.com/sharkdp/fd/releases/download/$FD/fd-$FD-x86_64-unknown-linux-musl.tar.gz"
tar -xzf ripgrep-*.tar.gz && tar -xzf fd-*.tar.gz
install -m755 ripgrep-*/rg ~/.local/bin/rg
install -m755 fd-*/fd ~/.local/bin/fd

# tree-sitter CLI: build from source (about 1 minute). Installs to ~/.cargo/bin/tree-sitter.
# If cargo is missing: curl https://sh.rustup.rs -sSf | sh
cargo install --locked tree-sitter-cli
```

### 2.7 Generic Linux, modern glibc (user-local, no sudo)
```sh
ARCH=x86_64   # or arm64
mkdir -p ~/.local/bin ~/.local/opt
curl -fsSL -o /tmp/nvim.tar.gz \
  https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$ARCH.tar.gz
tar -xzf /tmp/nvim.tar.gz -C ~/.local/opt
ln -sf ~/.local/opt/nvim-linux-$ARCH/bin/nvim ~/.local/bin/nvim

# tree-sitter CLI binary (fall back to cargo, as in 2.6, on a GLIBC error)
TSARCH=x64    # or arm64
curl -fsSL https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-$TSARCH.gz \
  | gunzip > ~/.local/bin/tree-sitter && chmod +x ~/.local/bin/tree-sitter
tree-sitter --version
```

---

## 3. Write the config

Config location: run `nvim --headless +'lua io.write(vim.fn.stdpath("config"))' +q`.
This is usually `~/.config/nvim` on Linux/macOS and `%LOCALAPPDATA%\nvim` on Windows. Write the file below to `<config>/init.lua`.

### 3.1 `init.lua`
```lua
-- Leader key = Space. Most custom shortcuts below start with it (e.g. Space f = find files).
-- Must be set before any <leader> mappings are created.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

----------------------------------------------------------------------------------------------
-- Basic options
----------------------------------------------------------------------------------------------

-- Line numbers: absolute number on the current line, relative distance on the rest
vim.opt.number = true
vim.opt.relativenumber = true

-- Search is case-insensitive unless you type a capital letter
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep a few lines visible above/below the cursor when scrolling
vim.opt.scrolloff = 8

-- New splits open to the right / below (like VS Code) instead of left / above
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Always show the error/warning column so text doesn't jump sideways when one appears
vim.opt.signcolumn = "yes"

-- Bright line numbers; the current line's number is bold yellow
vim.opt.cursorline = true
vim.opt.cursorlineopt = "number"
local function bright_line_numbers()
  for _, group in ipairs({ "LineNr", "LineNrAbove", "LineNrBelow" }) do
    vim.api.nvim_set_hl(0, group, { fg = "#e4e4e4", ctermfg = 254 })
  end
  vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#ffd700", ctermfg = 220, bold = true })
end
bright_line_numbers()
-- Re-apply if you ever switch colorschemes
vim.api.nvim_create_autocmd("ColorScheme", { callback = bright_line_numbers })

----------------------------------------------------------------------------------------------
-- Shortcuts
----------------------------------------------------------------------------------------------

-- Press Esc to clear search highlighting
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

vim.keymap.set("n", "<leader>w", "<cmd>write<CR>", { desc = "Save file" })
vim.keymap.set("n", "<leader>q", "<cmd>quit<CR>", { desc = "Close window" })
vim.keymap.set("n", "<leader>v", "<cmd>vsplit<CR>", { desc = "Split side by side" })
vim.keymap.set("n", "<leader>s", "<cmd>split<CR>", { desc = "Split top/bottom" })

-- Ctrl + h/j/k/l moves between split windows
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Window left" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Window down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Window up" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Space T = open a terminal, then press one key for where it goes:
--   l = right, j = below, h = left, k = above, t = new tab, Enter = in this window, Esc = cancel
-- Inside the terminal, Ctrl-h/j/k/l jumps straight to another window, same as everywhere else.
-- Esc twice stops typing into it without leaving (to scroll or copy its output).
local terminal_places = {
  l = "rightbelow vsplit",
  j = "rightbelow split",
  h = "leftabove vsplit",
  k = "leftabove split",
  t = "tabnew",
  ["\r"] = "", -- Enter: no split
}
local function open_terminal()
  vim.api.nvim_echo({ { "Terminal: l=right j=below h=left k=above t=tab Enter=here", "Question" } }, false, {})
  local ok, key = pcall(vim.fn.getcharstr) -- wait for one key press
  vim.api.nvim_echo({ { "" } }, false, {}) -- clear the prompt
  local place = ok and terminal_places[key]
  if not place then
    return -- Esc or any other key cancels
  end
  if place ~= "" then
    vim.cmd(place)
  end
  vim.cmd.terminal()
  vim.cmd.startinsert() -- start typing into the shell right away
end
vim.keymap.set("n", "<leader>T", open_terminal, { desc = "Open terminal (asks where)" })
vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Stop typing into terminal" })
-- (This takes over the shell's own Ctrl-l "clear screen"; type `clear` instead.)
for _, key in ipairs({ "h", "j", "k", "l" }) do
  vim.keymap.set("t", "<C-" .. key .. ">", [[<C-\><C-n><C-w>]] .. key, { desc = "Window " .. key })
end
-- Moving into a terminal window puts you straight back into typing mode
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "term://*",
  callback = function()
    vim.cmd.startinsert()
  end,
})

----------------------------------------------------------------------------------------------
-- Plugins (installed by Neovim's built-in plugin manager, vim.pack)
-- Update them with :lua vim.pack.update()
----------------------------------------------------------------------------------------------

-- Build steps some plugins need after install/update. Must be registered before vim.pack.add().
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == "telescope-fzf-native.nvim" and (kind == "install" or kind == "update") then
      if vim.fn.executable("make") == 1 then -- optional speedup; telescope works without it
        vim.system({ "make" }, { cwd = ev.data.path }):wait()
      end
    elseif name == "nvim-treesitter" and kind == "update" then
      if not ev.data.active then
        vim.cmd.packadd("nvim-treesitter")
      end
      vim.cmd("TSUpdate")
    end
  end,
})

local function gh(repo)
  return "https://github.com/" .. repo
end

vim.pack.add({
  gh("nvim-lualine/lualine.nvim"),
  gh("nvim-lua/plenary.nvim"),
  gh("nvim-telescope/telescope.nvim"),
  gh("nvim-telescope/telescope-fzf-native.nvim"),
  { src = gh("nvim-treesitter/nvim-treesitter"), version = "main" },
  gh("neovim/nvim-lspconfig"),
  gh("mason-org/mason.nvim"),
  gh("mason-org/mason-lspconfig.nvim"),
  gh("hrsh7th/nvim-cmp"),
  gh("hrsh7th/cmp-nvim-lsp"),
  gh("hrsh7th/cmp-buffer"),
  gh("hrsh7th/cmp-path"),
  gh("windwp/nvim-autopairs"),
  gh("MunifTanjim/nui.nvim"),
  { src = gh("nvim-neo-tree/neo-tree.nvim"), version = vim.version.range("3") },
}, { confirm = false })

-- Status bar (the "NORMAL > file > ..." line at the bottom).
-- Set nerd_font = true once your terminal uses a Nerd Font (https://www.nerdfonts.com)
-- to get the arrow-shaped separators and file icons.
local nerd_font = false
vim.opt.showmode = false -- lualine already shows the mode
require("lualine").setup({
  options = nerd_font and {} or {
    icons_enabled = false,
    section_separators = { left = "▌", right = "▐" },
    component_separators = { left = "│", right = "│" },
  },
})

-- Telescope: fuzzy finder for files, text, and more. Type to filter, Enter to open, Esc to close.
local telescope = require("telescope")
local builtin = require("telescope.builtin")
telescope.setup({})
pcall(telescope.load_extension, "fzf") -- faster sorting, if the build step succeeded
vim.keymap.set("n", "<leader>f", builtin.find_files, { desc = "Find files" })
vim.keymap.set("n", "<leader>g", builtin.live_grep, { desc = "Grep text in all files" })
vim.keymap.set("n", "<leader>*", builtin.grep_string, { desc = "Grep word under cursor" })
vim.keymap.set("n", "<leader>/", builtin.current_buffer_fuzzy_find, { desc = "Search this file" })
vim.keymap.set("n", "<leader>b", builtin.buffers, { desc = "Open files (buffers)" })
vim.keymap.set("n", "<leader>o", builtin.oldfiles, { desc = "Recently opened files" })
vim.keymap.set("n", "<leader>d", builtin.diagnostics, { desc = "List errors/warnings" })
vim.keymap.set("n", "<leader>k", builtin.keymaps, { desc = "Search all shortcuts" })
vim.keymap.set("n", "<leader>h", builtin.help_tags, { desc = "Search help" })
-- Fuzzy-filter files changed in git (new/modified/deleted) with a diff preview.
-- Inside one repo this is Telescope's git_status (Tab = stage/unstage). In a folder holding
-- several repos (e.g. a Brazil workspace or its src/), it lists changes from all of them.
-- Status codes are git's: " M" = modified, "??" = new (untracked), "A " = added, " D" = deleted.
local function git_changed_files()
  local cwd = vim.fn.getcwd()
  -- Ask git rather than looking for a .git folder: tools can leave a stray, empty .git behind
  if vim.system({ "git", "-C", cwd, "rev-parse", "--is-inside-work-tree" }):wait().code == 0 then
    return builtin.git_status()
  end

  local repos = {}
  for _, pattern in ipairs({ "*/.git", "*/*/.git" }) do
    for _, git_dir in ipairs(vim.fn.globpath(cwd, pattern, false, true)) do
      table.insert(repos, vim.fs.dirname(git_dir))
    end
  end
  if #repos == 0 then
    return vim.notify("No git repos in " .. cwd, vim.log.levels.WARN)
  end
  table.sort(repos)

  -- Run git status in every repo at once, then collect the results
  local jobs = {}
  for i, repo in ipairs(repos) do
    jobs[i] = vim.system({ "git", "-C", repo, "status", "--porcelain", "-z", "-uall" })
  end
  local changes = {}
  for i, repo in ipairs(repos) do
    local fields = vim.split(jobs[i]:wait().stdout or "", "\0", { trimempty = true })
    local skip_next = false
    for _, field in ipairs(fields) do
      if skip_next then
        skip_next = false -- old name of a renamed/copied file
      else
        local status, file = field:sub(1, 2), field:sub(4)
        skip_next = status:find("[RC]") ~= nil
        table.insert(changes, { status = status, repo = repo, file = file, path = repo .. "/" .. file })
      end
    end
  end
  if #changes == 0 then
    return vim.notify("No changes in " .. #repos .. " repos", vim.log.levels.INFO)
  end

  local conf = require("telescope.config").values
  require("telescope.pickers").new({}, {
    prompt_title = "Git changed files (" .. #repos .. " repos)",
    finder = require("telescope.finders").new_table({
      results = changes,
      entry_maker = function(change)
        local display = change.status .. " " .. change.path:sub(#cwd + 2)
        return { value = change, display = display, ordinal = display, path = change.path }
      end,
    }),
    sorter = conf.file_sorter({}),
    previewer = require("telescope.previewers").new_buffer_previewer({
      title = "Git File Diff Preview",
      define_preview = function(self, entry)
        local change = entry.value
        if change.status == "??" or change.status == "A " then -- new file: show its contents
          conf.buffer_previewer_maker(change.path, self.state.bufnr, { bufname = self.state.bufname })
        else
          local diff = vim.system({ "git", "-C", change.repo, "--no-pager", "diff", "HEAD", "--", change.file }):wait()
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(diff.stdout or "", "\n"))
          require("telescope.previewers.utils").highlighter(self.state.bufnr, "diff")
        end
      end,
    }),
  }):find()
end
vim.keymap.set("n", "<leader>c", git_changed_files, { desc = "Git changed files" })

-- File tree sidebar, like VS Code's Explorer. Space t = show/hide.
-- Inside the tree: Enter = open, a = new file (end name with / for a folder), d = delete,
-- r = rename, H = show hidden files, / = filter by name, ? = list all tree keys,
-- < and > = switch view between Files / Open buffers / Git (only changed files).
-- Changed files are colored and tagged: M = modified, ? = new (untracked), A = added, D = deleted.
require("neo-tree").setup({
  close_if_last_window = true, -- quit Neovim instead of leaving just the tree open
  filesystem = {
    follow_current_file = { enabled = true }, -- highlight the file you're editing
    use_libuv_file_watcher = true, -- refresh when files change on disk
  },
  default_component_configs = nerd_font and {} or {
    icon = { folder_closed = "▸", folder_open = "▾", folder_empty = "▹", folder_empty_open = "▿" },
    git_status = {
      symbols = {
        added = "A", modified = "M", deleted = "D", renamed = "R", untracked = "?",
        ignored = "i", conflict = "!", unstaged = "", staged = "S",
      },
    },
  },
})
vim.keymap.set("n", "<leader>t", "<cmd>Neotree toggle<CR>", { desc = "Toggle file tree" })

-- Treesitter: accurate syntax highlighting. Parsers are compiled by the tree-sitter CLI.
if vim.fn.executable("tree-sitter") == 1 then
  require("nvim-treesitter").install({
    "c", "cpp", "python", "bash", "lua", "vim", "vimdoc", "markdown", "markdown_inline",
    "json", "yaml", "make",
  })
end
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    pcall(vim.treesitter.start, args.buf) -- quietly skip languages without a parser
  end,
})

-- Autocomplete popup while typing.
--   Tab / Shift-Tab: move through suggestions   Enter: accept   Ctrl-Space: open   Ctrl-e: close
local cmp = require("cmp")
cmp.setup({
  snippet = {
    expand = function(args)
      vim.snippet.expand(args.body)
    end,
  },
  sources = cmp.config.sources({ { name = "nvim_lsp" }, { name = "path" } }, { { name = "buffer" } }),
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"] = cmp.mapping.confirm({ select = false }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then cmp.select_next_item() else fallback() end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then cmp.select_prev_item() else fallback() end
    end, { "i", "s" }),
  }),
  window = {
    completion = cmp.config.window.bordered(),
    documentation = cmp.config.window.bordered(),
  },
})

-- Auto-close brackets and quotes; also adds () after accepting a function from autocomplete
require("nvim-autopairs").setup({})
cmp.event:on("confirm_done", require("nvim-autopairs.completion.cmp").on_confirm_done())

-- LSP: code smarts (go to definition, references, rename, inline errors).
-- Mason installs the language servers; run :Mason to browse and add more (e.g. pyright for Python).
vim.diagnostic.config({ virtual_text = true, severity_sort = true, float = { border = "rounded" } })
vim.lsp.config("*", { capabilities = require("cmp_nvim_lsp").default_capabilities() })
vim.lsp.config("clangd", { cmd = { "clangd", "--background-index", "--header-insertion=never" } })
require("mason").setup()
require("mason-lspconfig").setup({ ensure_installed = { "clangd" } })

-- Built-in LSP keys (work automatically): K = docs, grr = references, grn = rename,
-- gra = code actions/fixes, gri = implementation, ]d / [d = next/prev error, Ctrl-o = jump back
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local opts = { buffer = args.buf }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to definition" }))
    vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, vim.tbl_extend("force", opts, { desc = "Show error on this line" }))
  end,
})
```

### 3.2 Optional: pin the exact plugin versions
`vim.pack` writes a lockfile at `<config>/nvim-pack-lock.json`. To reproduce the exact plugin commits from the original build, write this file **before** the first launch. Skip it to get the latest versions.
```json
{
  "plugins": {
    "cmp-buffer": {
      "rev": "b74fab3656eea9de20a9b8116afa3cfc4ec09657",
      "src": "https://github.com/hrsh7th/cmp-buffer"
    },
    "cmp-nvim-lsp": {
      "rev": "cbc7b02bb99fae35cb42f514762b89b5126651ef",
      "src": "https://github.com/hrsh7th/cmp-nvim-lsp"
    },
    "cmp-path": {
      "rev": "c642487086dbd9a93160e1679a1327be111cbc25",
      "src": "https://github.com/hrsh7th/cmp-path"
    },
    "lualine.nvim": {
      "rev": "221ce6b2d999187044529f49da6554a92f740a96",
      "src": "https://github.com/nvim-lualine/lualine.nvim"
    },
    "mason-lspconfig.nvim": {
      "rev": "00b5473cca4db5b410ff4bae724e3b6e21f2687f",
      "src": "https://github.com/mason-org/mason-lspconfig.nvim"
    },
    "mason.nvim": {
      "rev": "2a6940af80375532e5e9e7c1f2fc6319a1b7a69d",
      "src": "https://github.com/mason-org/mason.nvim"
    },
    "neo-tree.nvim": {
      "rev": "f3f3bf73414e400cf9fc13fda50f00404a8f8ab1",
      "src": "https://github.com/nvim-neo-tree/neo-tree.nvim",
      "version": "3.0.0 - 4.0.0"
    },
    "nui.nvim": {
      "rev": "10fc361835c856ba4233ef5ea135b919bf3dce97",
      "src": "https://github.com/MunifTanjim/nui.nvim"
    },
    "nvim-autopairs": {
      "rev": "3172f40c16563db871a58f20d205c710ad782311",
      "src": "https://github.com/windwp/nvim-autopairs"
    },
    "nvim-cmp": {
      "rev": "2ffe79f1f021def8dd1fcd81deb16f1bb0d989f3",
      "src": "https://github.com/hrsh7th/nvim-cmp"
    },
    "nvim-lspconfig": {
      "rev": "45a3a444b710511c39abca3b60bb6e23a21e3de5",
      "src": "https://github.com/neovim/nvim-lspconfig"
    },
    "nvim-treesitter": {
      "rev": "ca581c3436fc2b236847f5b739ebc263739e5ca6",
      "src": "https://github.com/nvim-treesitter/nvim-treesitter",
      "version": "'main'"
    },
    "plenary.nvim": {
      "rev": "74b06c6c75e4eeb3108ec01852001636d85a932b",
      "src": "https://github.com/nvim-lua/plenary.nvim"
    },
    "telescope-fzf-native.nvim": {
      "rev": "b25b749b9db64d375d782094e2b9dce53ad53a40",
      "src": "https://github.com/nvim-telescope/telescope-fzf-native.nvim"
    },
    "telescope.nvim": {
      "rev": "40aedd8a68c78a656a10a8d62d80c54af59420fb",
      "src": "https://github.com/nvim-telescope/telescope.nvim"
    }
  }
}
```

---

## 4. Bootstrap headlessly

Run these in order. Each one blocks until it finishes.

```sh
# 1. Clone all plugins. The PackChanged hook in init.lua builds telescope-fzf-native with make.
nvim --headless +qa

# 2. Compile Tree-sitter parsers synchronously. On a normal launch this runs in the background.
nvim --headless +'lua require("nvim-treesitter").install({"c","cpp","python","bash","lua","vim","vimdoc","markdown","markdown_inline","json","yaml","make"}):wait(300000)' +qa

# 3. Install clangd through Mason. mason-lspconfig would also install it on first normal launch.
nvim --headless +'MasonInstall clangd' +qa
```

Where things land (Linux/macOS): plugins in `~/.local/share/nvim/site/pack/core/opt/`, parsers in `~/.local/share/nvim/site/parser/`, and Mason servers in `~/.local/share/nvim/mason/bin/`.

---

## 5. Verify

Save this as `check.lua` in an empty temp dir. Next to it, create `t.c`:
```c
#include <stdio.h>
static int add(int a, int b) { return a + b; }
int main(void) {
  int x = add(1, 2);
  printf("%d\n", x);
  return undefined_var;
}
```
```lua
vim.wait(15000, function() return #vim.lsp.get_clients({ bufnr = 0 }) > 0 end)
vim.wait(15000, function() return #vim.diagnostic.get(0) > 0 end)
local out = {}
table.insert(out, "lsp clients: " .. table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({ bufnr = 0 })), ","))
table.insert(out, "treesitter active: " .. tostring(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil))
table.insert(out, "fzf ext: " .. tostring(pcall(function() return require("telescope").extensions.fzf end)))
for _, d in ipairs(vim.diagnostic.get(0)) do table.insert(out, "diag L" .. (d.lnum + 1) .. ": " .. d.message) end
local ok = pcall(require("telescope.builtin").find_files)
table.insert(out, "telescope find_files: " .. tostring(ok))
table.insert(out, "neo-tree: " .. tostring(vim.fn.exists(":Neotree") == 2))
local msgs = vim.api.nvim_exec2("messages", { output = true }).output
table.insert(out, "startup messages: " .. (msgs == "" and "(none)" or msgs))
io.write(table.concat(out, "\n") .. "\n")
vim.cmd("qa!")
```
Run it with `cd <tempdir> && nvim --headless t.c -c "luafile check.lua"`. Expected output:
```
lsp clients: clangd
treesitter active: true
fzf ext: true
diag L6: Use of undeclared identifier 'undefined_var'
telescope find_files: true
neo-tree: true
startup messages: (none)
```
`fzf ext: false` is acceptable when `make` is missing; telescope falls back to its default sorter.

---

## 6. Plugins

| Plugin | Repo | Purpose |
|---|---|---|
| lualine.nvim | nvim-lualine/lualine.nvim | status bar showing mode (NORMAL/INSERT), file, git branch, position |
| plenary.nvim | nvim-lua/plenary.nvim | Lua library that telescope needs |
| telescope.nvim | nvim-telescope/telescope.nvim | fuzzy finder for files, grep, buffers, keymaps, help, diagnostics |
| telescope-fzf-native.nvim | nvim-telescope/telescope-fzf-native.nvim | native fast sorter for telescope (needs `make`) |
| nvim-treesitter (`main` branch) | nvim-treesitter/nvim-treesitter | installs parsers; highlighting is started via `vim.treesitter.start` |
| nvim-lspconfig | neovim/nvim-lspconfig | default server configs consumed by `vim.lsp.config` |
| mason.nvim | mason-org/mason.nvim | installs language servers (`:Mason`) |
| mason-lspconfig.nvim | mason-org/mason-lspconfig.nvim | auto-installs `clangd` and auto-enables installed servers |
| nvim-cmp | hrsh7th/nvim-cmp | autocomplete popup |
| cmp-nvim-lsp / cmp-buffer / cmp-path | hrsh7th/* | completion sources: LSP, words in the buffer, file paths |
| nvim-autopairs | windwp/nvim-autopairs | auto-closes brackets and quotes; adds `()` after accepting a function |
| nui.nvim | MunifTanjim/nui.nvim | UI component library that neo-tree needs |
| neo-tree.nvim (v3.x) | nvim-neo-tree/neo-tree.nvim | file tree sidebar with git status markers; pinned to `vim.version.range("3")` |

Language server: **clangd** (C/C++), started with `--background-index --header-insertion=never`. To add Python, run `:Mason`, find `pyright`, and press `i` to install. mason-lspconfig enables it automatically.

---

## 7. Keymaps (for the human)

Leader is **Space**.

| Keys | Action |
|---|---|
| `Space f` / `Space g` / `Space *` | find file / grep all files / grep word under cursor |
| `Space /` / `Space b` / `Space o` | search this file / open buffers / recent files |
| `Space d` / `Space k` / `Space h` | list diagnostics / search keymaps / search help |
| `Space c` | git changed files with diff preview (current repo, or every repo one or two levels down) |
| `Space t` | show / hide the file tree |
| In the tree: `Enter` / `a` / `d` / `r` | open / new file (end with `/` for a folder) / delete / rename |
| In the tree: `H` / `/` / `?` / `<` `>` | toggle hidden files / filter / list tree keys / switch Files, Buffers, Git views |
| `Space w` / `Space q` | save / close window |
| `Space v` / `Space s` | vertical / horizontal split (new splits open right / below) |
| `Ctrl-h/j/k/l` | move between splits (also works from inside a terminal) |
| `Space T`, then `l` / `j` / `h` / `k` / `t` / `Enter` | open a terminal right / below / left / above / new tab / in this window (`Esc` cancels) |
| `Esc Esc` (in terminal) | stop typing into the terminal (to scroll or copy); entering a terminal window resumes typing |
| `Esc` (normal mode) | clear search highlight |
| `gd` / `Ctrl-o` | go to definition / jump back |
| `grr` / `grn` / `gra` / `gri` | references / rename / code action / implementation (Neovim built-ins) |
| `K` | hover docs |
| `]d` / `[d` / `Space e` | next / previous diagnostic / show the full diagnostic |
| Completion: `Tab` / `Shift-Tab` / `Enter` / `Ctrl-Space` / `Ctrl-e` | next / previous / accept / open / close |

---

## 8. Gotchas

- **`GLIBC_2.xx not found`**: use the old-glibc builds (2.6). For Neovim, use `neovim/neovim-releases`. For tree-sitter, use `cargo install --locked tree-sitter-cli`. For rg and fd, use the `*-unknown-linux-musl` assets.
- **`api.github.com` returns 403** (rate limit on shared IPs): plain `github.com/.../releases/latest/download/...` and `/releases/latest` redirects still work.
- **tree-sitter CLI from npm**: nvim-treesitter explicitly says not to use it. Use the system package, the official binary, or cargo.
- **Missing parsers**: if `tree-sitter` isn't on `PATH` at startup, the config skips parser installs and highlighting falls back to regex syntax. Install the CLI, then rerun step 2 of section 4.
- **Inline errors**: Neovim ≥ 0.11 turns diagnostic virtual text off by default. This config turns it back on.
- **Nerd Font**: the status bar and file tree use plain separators, `▸`/`▾` folder markers, and letter git markers (`M`, `?`, `A`, `D`) by default. Set `local nerd_font = true` in `init.lua` once the terminal uses a Nerd Font, to get arrow separators and icons in both.
- **Terminal `Ctrl-l`**: the terminal-mode `Ctrl-h/j/k/l` window mappings take over the shell's own `Ctrl-l` (clear screen). Type `clear` instead.
- **`Space c` outside a repo**: when the current directory isn't inside a git work tree, it scans `*/.git` and `*/*/.git` under it (e.g. a Brazil workspace root or its `src/`). Repos nested deeper aren't found; `cd` closer to them first.
- **clangd in real projects**: clangd needs `compile_commands.json` (or a `.clangd` file) at the project root. Without it, you'll see "file not found" errors for project headers and limited cross-file navigation.
- **Updating plugins**: run `:lua vim.pack.update()`, review the confirmation buffer, then `:w` to apply. Run `:TSUpdate` for parsers (the config's hook does this after nvim-treesitter updates), and `:Mason` then `U` for servers.
- **Uninstall**: remove the Neovim install directory (e.g. `~/.local/opt/nvim-linux-x86_64` plus the `~/.local/bin/nvim` symlink), `<config>`, and the data dir (`~/.local/share/nvim`).
