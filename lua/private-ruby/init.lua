-- private-ruby/init.lua
-- Plugin entrypoint for private-ruby.nvim

local config = require("private-ruby.config")
local detect = require("private-ruby.detect")
local render = require("private-ruby.render")

local M = {}

local augroup_name = "PrivateRuby"

--- Refresh private method indicators for a buffer
---@param bufnr? integer Buffer number (defaults to current)
function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local cfg = config.get()

  local marks = detect.detect(bufnr)

  -- Format marks with text
  for _, mark in ipairs(marks) do
    mark.text = cfg.indicator.text
    mark.hl = cfg.indicator.hl
  end

  render.render(bufnr, marks, cfg)
end

--- Clear all indicators from a buffer
---@param bufnr? integer Buffer number (defaults to current)
function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  render.clear(bufnr)
end

--- Setup autocmds for a Ruby buffer
---@param bufnr integer
local function setup_buffer_autocmds(bufnr)
  local group_name = augroup_name .. bufnr

  -- Skip if already setup for this buffer
  local ok = pcall(vim.api.nvim_get_autocmds, { group = group_name })
  if ok then
    return
  end

  local group = vim.api.nvim_create_augroup(group_name, { clear = true })

  -- Refresh on buffer write
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    buffer = bufnr,
    callback = function()
      M.refresh(bufnr)
    end,
  })

  -- Cleanup augroup on buffer delete
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    buffer = bufnr,
    callback = function()
      vim.api.nvim_del_augroup_by_name(group_name)
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
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup_name,
    pattern = "ruby",
    callback = function(args)
      setup_buffer_autocmds(args.buf)
    end,
  })

  -- User commands (only create if they don't exist)
  if vim.fn.exists(":PrivateRubyRefresh") == 0 then
    vim.api.nvim_create_user_command("PrivateRubyRefresh", function()
      local bufnr = vim.api.nvim_get_current_buf()
      if vim.bo[bufnr].filetype == "ruby" then
        M.refresh(bufnr)
      end
    end, { desc = "Refresh private method indicators" })
  end

  if vim.fn.exists(":PrivateRubyClear") == 0 then
    vim.api.nvim_create_user_command("PrivateRubyClear", function()
      local bufnr = vim.api.nvim_get_current_buf()
      if vim.bo[bufnr].filetype == "ruby" then
        M.clear(bufnr)
      end
    end, { desc = "Clear private method indicators" })
  end

  -- Apply to any existing Ruby buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local ft = vim.bo[bufnr].filetype
      if ft == "ruby" then
        setup_buffer_autocmds(bufnr)
      end
    end
  end
end

return M
