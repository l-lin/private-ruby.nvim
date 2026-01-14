-- private-ruby/config.lua
-- Configuration management for private-ruby.nvim

local M = {}

---@class PrivateRubyScope
---@field kind string 'module' | 'class' | 'singleton'
---@field name? string Name of module/class

---@class PrivateRubyContext
---@field method_name string Method name
---@field is_singleton boolean Whether it's a singleton method
---@field scope PrivateRubyScope[] Enclosing scopes

---@class PrivateRubyIndicator
---@field text string Default indicator text
---@field hl string Highlight group
---@field position string 'eol' | 'gutter'
---@field prefix string Prefix before indicator (only for eol)
---@field format? fun(ctx: PrivateRubyContext): string Custom formatter

---@class PrivateRubyConfig
---@field indicator PrivateRubyIndicator Indicator options

---@type PrivateRubyConfig
local defaults = {
  indicator = {
    text = '',
    hl = 'DiagnosticError',
    position = 'gutter',
    prefix = '',
    format = nil,
  },
}

---@type PrivateRubyConfig
local config = vim.deepcopy(defaults)

--- Setup configuration with user options
---@param opts? PrivateRubyConfig User options
function M.setup(opts)
  opts = opts or {}
  config = vim.tbl_deep_extend('force', defaults, opts)
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
