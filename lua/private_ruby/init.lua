-- private_ruby/init.lua
-- Plugin entrypoint for private-ruby.nvim

local config = require('private_ruby.config')
local detect = require('private_ruby.detect')
local render = require('private_ruby.render')

local M = {}

local augroup_name = 'PrivateRuby'

--- Format a mark's text using config
---@param mark table Mark from detect
---@param cfg table Config
---@return string
local function format_mark_text(mark, cfg)
  local indicator = cfg.indicator
  if indicator.format then
    return indicator.format({
      method_name = mark.method_name,
      is_singleton = mark.is_singleton,
      scope = mark.scope,
    })
  end
  return indicator.text
end

--- Refresh private method indicators for a buffer
---@param bufnr? integer Buffer number (defaults to current)
function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cfg = config.get()

  if not cfg.enabled then
    render.clear(bufnr)
    return
  end

  local marks = detect.detect(bufnr)

  -- Format marks with text
  for _, mark in ipairs(marks) do
    mark.text = format_mark_text(mark, cfg)
    mark.hl = cfg.indicator.hl
  end

  render.render(bufnr, marks, cfg)
end

--- Clear all indicators from a buffer
---@param bufnr? integer Buffer number (defaults to current)
function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  render.clear(bufnr)
end

--- Setup autocmds for a Ruby buffer
---@param bufnr integer
local function setup_buffer_autocmds(bufnr)
  local group = vim.api.nvim_create_augroup(augroup_name .. bufnr, { clear = true })

  -- Refresh on buffer read and write
  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
    group = group,
    buffer = bufnr,
    callback = function()
      M.refresh(bufnr)
    end,
  })

  -- Initial refresh
  M.refresh(bufnr)
end

--- Setup the plugin
---@param opts? table User configuration
function M.setup(opts)
  config.setup(opts)

  -- Clear existing autocmds
  vim.api.nvim_create_augroup(augroup_name, { clear = true })

  -- Setup for Ruby filetypes
  vim.api.nvim_create_autocmd('FileType', {
    group = augroup_name,
    pattern = 'ruby',
    callback = function(args)
      setup_buffer_autocmds(args.buf)
    end,
  })

  -- User command
  vim.api.nvim_create_user_command('PrivateRubyRefresh', function()
    M.refresh()
  end, { desc = 'Refresh private method indicators' })

  -- Apply to any existing Ruby buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local ft = vim.bo[bufnr].filetype
      if ft == 'ruby' then
        setup_buffer_autocmds(bufnr)
      end
    end
  end
end

return M
