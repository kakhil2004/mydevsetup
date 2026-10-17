-- Run with: nvim --headless t.c -c "luafile check.lua"
-- Prints one status line per feature. Always quits, even if a check errors,
-- so a broken setup fails the test instead of hanging it.
local function main()
  vim.wait(15000, function() return #vim.lsp.get_clients({ bufnr = 0 }) > 0 end)
  vim.wait(15000, function() return #vim.diagnostic.get(0) > 0 end)
  local out = {}
  table.insert(out, "lsp clients: " .. table.concat(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({ bufnr = 0 })), ","))
  table.insert(out, "treesitter active: " .. tostring(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil))
  table.insert(out, "fzf ext: " .. tostring(pcall(function() return require("telescope").extensions.fzf end)))
  for _, d in ipairs(vim.diagnostic.get(0)) do table.insert(out, "diag L" .. (d.lnum + 1) .. ": " .. d.message) end
  local ok = pcall(function() require("telescope.builtin").find_files() end)
  table.insert(out, "telescope find_files: " .. tostring(ok))
  local msgs = vim.api.nvim_exec2("messages", { output = true }).output
  table.insert(out, "startup messages: " .. (msgs == "" and "(none)" or msgs))
  io.write(table.concat(out, "\n") .. "\n")
end

local ok, err = xpcall(main, debug.traceback)
if not ok then io.write("check.lua error: " .. err .. "\n") end
vim.cmd("qa!")
