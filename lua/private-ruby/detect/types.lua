-- private-ruby/detect/types.lua
-- Shared types for detection modules

---@class PrivateRubyMark
---@field lnum integer 0-based line number
---@field method_name string Method name
---@field is_singleton boolean Whether it's a singleton method
---@field scope table[] Scope stack
---@field text? string Indicator text (set by init.lua before rendering)
---@field hl? string Highlight group (set by init.lua before rendering)

---@class ScopeFrame
---@field kind string 'module' | 'class' | 'singleton' | 'method' | 'block'
---@field name? string Name of module/class
---@field visibility string 'public' | 'protected' | 'private'

local M = {}

--- Create a new scope frame
---@param kind string
---@param name? string
---@return ScopeFrame
function M.new_frame(kind, name)
  return {
    kind = kind,
    name = name,
    visibility = "public",
  }
end

return M
