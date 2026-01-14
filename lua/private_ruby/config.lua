-- private_ruby/config.lua
-- Configuration management for private-ruby.nvim

local M = {}

---@class PrivateRubyIndicator
---@field text string Default indicator text
---@field hl string Highlight group
---@field position string Virtual text position ('eol')
---@field prefix string Prefix before indicator
---@field format? fun(ctx: PrivateRubyContext): string Custom formatter

---@class PrivateRubyConfig
---@field enabled boolean Enable the plugin
---@field indicator PrivateRubyIndicator Indicator options

---@type PrivateRubyConfig
local defaults = {
  enabled = true,
  indicator = {
    text = '🔒',
    hl = 'DiagnosticHint',
    position = 'eol',
    prefix = ' ',
    format = nil,
  },
}

---@type PrivateRubyConfig
local config = vim.deepcopy(defaults)

--- Deep merge two tables
---@param t1 table Base table
---@param t2 table Override table
---@return table Merged table
local function deep_merge(t1, t2)
  local result = vim.deepcopy(t1)
  for k, v in pairs(t2) do
    if type(v) == 'table' and type(result[k]) == 'table' then
      result[k] = deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

--- Setup configuration with user options
---@param opts? PrivateRubyConfig User options
function M.setup(opts)
  opts = opts or {}
  config = deep_merge(defaults, opts)
end

--- Get current configuration
---@return PrivateRubyConfig
function M.get()
  return config
end

--- Reset configuration to defaults
function M.reset()
  config = vim.deepcopy(defaults)
end

return M
