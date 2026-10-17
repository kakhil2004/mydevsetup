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
