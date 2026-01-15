-- private-ruby/types.lua
-- Shared types for private-ruby.nvim

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

---@class PrivateRubyDetect
---@field kind string 'treesitter' | 'regex' | 'auto'

---@class PrivateRubyConfig
---@field indicator PrivateRubyIndicator Indicator options
---@field detect PrivateRubyDetect Detection options

return {}
