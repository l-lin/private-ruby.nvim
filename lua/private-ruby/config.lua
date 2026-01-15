-- private-ruby/config.lua
-- Configuration management for private-ruby.nvim

require('private-ruby.types') -- Load type definitions

local M = {}

---@type PrivateRubyConfig
local defaults = {
  indicator = {
    text = '',
    hl = 'DiagnosticHint',
    position = 'gutter',
    prefix = '',
  },
  detect = {
    kind = 'treesitter',
  },
}

---@type PrivateRubyConfig
local config = vim.deepcopy(defaults)

--- Setup configuration with user options
---@param opts? PrivateRubyConfig User options
function M.setup(opts)
  opts = opts or {}
  -- Ensure opts.indicator is a table (or nil) to avoid tbl_deep_extend errors
  if opts.indicator ~= nil and type(opts.indicator) ~= 'table' then
    opts.indicator = nil
  end
  -- Ensure opts.detect is a table (or nil) to avoid tbl_deep_extend errors
  if opts.detect ~= nil and type(opts.detect) ~= 'table' then
    opts.detect = nil
  end
  config = vim.tbl_deep_extend('force', defaults, opts)

  -- Validate detect.kind
  local valid_kinds = { treesitter = true, regex = true, auto = true }
  if not valid_kinds[config.detect.kind] then
    config.detect.kind = defaults.detect.kind
  end
end

--- Get current configuration
---@return PrivateRubyConfig
function M.get()
  return config
end

return M
