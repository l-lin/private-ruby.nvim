-- Minimal init for headless testing with mini.test
-- Usage: nvim --headless -u tests/minimal_init.lua -c "lua require('mini.test').run()" -c qa

-- Add plugin to runtime path
vim.opt.rtp:prepend(vim.fn.getcwd())

-- Add mini.nvim to runtime path (assumes mini.nvim is installed via mise or available)
-- Try common locations for mini.nvim
local mini_paths = {
  vim.fn.expand('~/.local/share/nvim/site/pack/*/start/mini.nvim'),
  vim.fn.expand('~/.local/share/nvim/site/pack/*/opt/mini.nvim'),
  vim.fn.expand('~/.local/share/nvim/lazy/mini.nvim'),
  vim.fn.stdpath('data') .. '/lazy/mini.nvim',
  vim.fn.getcwd() .. '/deps/mini.nvim',
}

local mini_found = false
for _, path_pattern in ipairs(mini_paths) do
  local paths = vim.fn.glob(path_pattern, false, true)
  if #paths > 0 then
    vim.opt.rtp:prepend(paths[1])
    mini_found = true
    break
  end
end

-- If mini.nvim not found, clone it to deps/
if not mini_found then
  local mini_path = vim.fn.getcwd() .. '/deps/mini.nvim'
  if vim.fn.isdirectory(mini_path) == 0 then
    vim.fn.system({
      'git', 'clone', '--filter=blob:none',
      'https://github.com/echasnovski/mini.nvim',
      mini_path
    })
  end
  vim.opt.rtp:prepend(mini_path)
end

-- Disable swap/backup for tests
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- Set up mini.test
require('mini.test').setup()
