-- private-ruby/detect.lua
-- Detect private Ruby methods using regex/line-scan

local M = {}

---@class PrivateRubyMark
---@field lnum integer 0-based line number
---@field method_name string Method name
---@field is_singleton boolean Whether it's a singleton method
---@field scope table[] Scope stack

-- Patterns for Ruby constructs
local PATTERNS = {
  -- Visibility directives (standalone keyword, optionally followed by comment)
  private = '^%s*private%s*$',
  private_with_comment = '^%s*private%s+#',
  public = '^%s*public%s*$',
  public_with_comment = '^%s*public%s+#',
  protected = '^%s*protected%s*$',
  protected_with_comment = '^%s*protected%s+#',

  -- Scope openers
  module = '^%s*module%s+([A-Z][%w_:]*)',
  class = '^%s*class%s+([A-Z][%w_:]*)',
  singleton_block = '^%s*class%s*<<%s*self%s*',

  -- Method definitions
  instance_method = '^%s*def%s+([a-zA-Z_][%w_]*[!?=]?)',
  singleton_method = '^%s*def%s+self%.([a-zA-Z_][%w_]*[!?=]?)',

  -- Scope closer (end as standalone keyword)
  scope_end = '^%s*end%s*$',
  scope_end_with_comment = '^%s*end%s+#',
}

---@class ScopeFrame
---@field kind string 'module' | 'class' | 'singleton' | 'method'
---@field name? string Name of module/class
---@field visibility string 'public' | 'protected' | 'private'

--- Create a new scope frame
---@param kind string
---@param name? string
---@return ScopeFrame
local function new_frame(kind, name)
  return {
    kind = kind,
    name = name,
    visibility = 'public', -- Default visibility
  }
end

--- Detect private methods in a buffer
---@param bufnr integer Buffer number
---@return PrivateRubyMark[]
function M.detect(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local marks = {}

  ---@type ScopeFrame[]
  local scope_stack = {}

  -- Helper to find the nearest non-method scope
  local function find_enclosing_scope()
    for i = #scope_stack, 1, -1 do
      if scope_stack[i].kind ~= 'method' then
        return scope_stack[i]
      end
    end
    return nil
  end

  -- Helper to get current visibility
  local function current_visibility()
    local scope = find_enclosing_scope()
    if not scope then
      return 'public'
    end
    return scope.visibility
  end

  -- Helper to set current visibility
  local function set_visibility(vis)
    local scope = find_enclosing_scope()
    if scope then
      scope.visibility = vis
    end
  end

  -- Helper to check if we're in a singleton block
  local function in_singleton_block()
    for _, frame in ipairs(scope_stack) do
      if frame.kind == 'singleton' then
        return true
      end
    end
    return false
  end

  -- Helper to build scope info for context (excludes method frames)
  local function build_scope()
    local scope = {}
    for _, frame in ipairs(scope_stack) do
      if frame.kind ~= 'method' then
        table.insert(scope, { kind = frame.kind, name = frame.name })
      end
    end
    return scope
  end

  for i, line in ipairs(lines) do
    local lnum = i - 1 -- 0-based

    -- Check for module
    local module_name = line:match(PATTERNS.module)
    if module_name then
      table.insert(scope_stack, new_frame('module', module_name))
      goto continue
    end

    -- Check for singleton block (class << self) - must check before class
    if line:match(PATTERNS.singleton_block) then
      table.insert(scope_stack, new_frame('singleton', nil))
      goto continue
    end

    -- Check for class
    local class_name = line:match(PATTERNS.class)
    if class_name then
      table.insert(scope_stack, new_frame('class', class_name))
      goto continue
    end

    -- Check for visibility directives
    if line:match(PATTERNS.private) or line:match(PATTERNS.private_with_comment) then
      set_visibility('private')
      goto continue
    end
    if line:match(PATTERNS.public) or line:match(PATTERNS.public_with_comment) then
      set_visibility('public')
      goto continue
    end
    if line:match(PATTERNS.protected) or line:match(PATTERNS.protected_with_comment) then
      set_visibility('protected')
      goto continue
    end

    -- Check for singleton method (def self.foo)
    local singleton_name = line:match(PATTERNS.singleton_method)
    if singleton_name then
      -- Singleton methods defined with `def self.foo` are NOT affected by
      -- instance-level `private` keyword, so we don't mark them here
      -- (They would need `private_class_method` which is v2)
      -- But we still need to track the method scope for proper end matching
      table.insert(scope_stack, new_frame('method', singleton_name))
      goto continue
    end

    -- Check for instance method
    local method_name = line:match(PATTERNS.instance_method)
    if method_name then
      local is_private = current_visibility() == 'private'
      local is_singleton = in_singleton_block()

      if is_private then
        table.insert(marks, {
          lnum = lnum,
          method_name = method_name,
          is_singleton = is_singleton,
          scope = build_scope(),
        })
      end
      -- Track method scope for proper end matching
      table.insert(scope_stack, new_frame('method', method_name))
      goto continue
    end

    -- Check for end
    if line:match(PATTERNS.scope_end) or line:match(PATTERNS.scope_end_with_comment) then
      if #scope_stack > 0 then
        table.remove(scope_stack)
      end
      goto continue
    end

    ::continue::
  end

  return marks
end

return M
