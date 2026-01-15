-- private-ruby/detect/regex.lua
-- Detect private Ruby methods using regex/line-scan

local types = require('private-ruby.detect.types')
local new_frame = types.new_frame

local M = {}

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

  -- Block openers (do blocks need tracking for proper end matching)
  -- Matches: do at end of line (with optional comment)
  block_do = '%s+do%s*$',
  block_do_with_comment = '%s+do%s+#',
  block_do_with_pipes = '%s+do%s*|',

  -- Control flow block openers (if/unless/case/begin/while/until/for)
  -- These all create blocks that end with `end`
  -- Must be at start of line (with optional indentation) to avoid matching postfix if/unless
  block_if = '^%s*if%s+',
  block_unless = '^%s*unless%s+',
  block_case = '^%s*case[%s$]',
  block_begin = '^%s*begin%s*$',
  block_begin_with_comment = '^%s*begin%s+#',
  block_while = '^%s*while%s+',
  block_until = '^%s*until%s+',
  block_for = '^%s*for%s+',

  -- Method definitions
  -- Matches: def foo, def foo!, def foo?, def foo=, def +, def [], def []=, etc.
  instance_method = '^%s*def%s+([a-zA-Z_][%w_]*[!?=]?)',
  instance_method_operator = '^%s*def%s+([%+%-%*/<>=!&|%^~%%]+)',
  instance_method_indexer = '^%s*def%s+(%[%]=?)',
  singleton_method = '^%s*def%s+self%.([a-zA-Z_][%w_]*[!?=]?)',
  singleton_method_operator = '^%s*def%s+self%.([%+%-%*/<>=!&|%^~%%]+)',
  singleton_method_indexer = '^%s*def%s+self%.(%[%]=?)',

  -- Endless method detection (Ruby 3.0+): def foo = expr or def foo(args) = expr
  -- Pattern: after method name (and optional parens), there's = followed by non-=
  -- We need to be careful not to match def ==(other) as endless
  endless_method_simple = '^%s*def%s+[%w_!?]+%s*=%s*[^=]', -- def foo = x
  endless_method_with_args = '^%s*def%s+[%w_!?]+%b()%s*=%s*[^=]', -- def foo(a) = x
  endless_singleton_simple = '^%s*def%s+self%.[%w_!?]+%s*=%s*[^=]', -- def self.foo = x
  endless_singleton_with_args = '^%s*def%s+self%.[%w_!?]+%b()%s*=%s*[^=]', -- def self.foo(a) = x

  -- Scope closer (end as standalone keyword)
  scope_end = '^%s*end%s*$',
  scope_end_with_comment = '^%s*end%s+#',
}

--- Detect private methods in a buffer
---@param bufnr integer Buffer number
---@return PrivateRubyMark[]
function M.detect(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local marks = {}

  ---@type ScopeFrame[]
  local scope_stack = {}

  -- Helper to find the nearest non-method/non-block scope
  local function find_enclosing_scope()
    for i = #scope_stack, 1, -1 do
      local kind = scope_stack[i].kind
      if kind ~= 'method' and kind ~= 'block' then
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

  -- Helper to build scope info for context (excludes method/block frames)
  local function build_scope()
    local scope = {}
    for _, frame in ipairs(scope_stack) do
      local kind = frame.kind
      if kind ~= 'method' and kind ~= 'block' then
        table.insert(scope, { kind = kind, name = frame.name })
      end
    end
    return scope
  end

  -- Helper to check if line is an endless method (def foo = expr)
  local function is_endless_method(line)
    -- Check for endless method patterns (Ruby 3.0+)
    -- Must check specific patterns to avoid matching def ==(other)
    return line:match(PATTERNS.endless_method_simple) ~= nil
      or line:match(PATTERNS.endless_method_with_args) ~= nil
      or line:match(PATTERNS.endless_singleton_simple) ~= nil
      or line:match(PATTERNS.endless_singleton_with_args) ~= nil
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

    -- Check for singleton method (def self.foo, def self.+, def self.[])
    local singleton_name = line:match(PATTERNS.singleton_method)
      or line:match(PATTERNS.singleton_method_operator)
      or line:match(PATTERNS.singleton_method_indexer)
    if singleton_name then
      -- Singleton methods defined with `def self.foo` are NOT affected by
      -- instance-level `private` keyword, so we don't mark them here
      -- (They would need `private_class_method` which is v2)
      -- But we still need to track the method scope for proper end matching
      -- (unless it's an endless method which has no end)
      if not is_endless_method(line) then
        table.insert(scope_stack, new_frame('method', singleton_name))
      end
      goto continue
    end

    -- Check for instance method (def foo, def +, def [])
    local method_name = line:match(PATTERNS.instance_method)
      or line:match(PATTERNS.instance_method_operator)
      or line:match(PATTERNS.instance_method_indexer)
    if method_name then
      local is_private = current_visibility() == 'private'
      local is_singleton = in_singleton_block()
      local endless = is_endless_method(line)

      if is_private then
        table.insert(marks, {
          lnum = lnum,
          method_name = method_name,
          is_singleton = is_singleton,
          scope = build_scope(),
        })
      end
      -- Track method scope for proper end matching (unless endless method)
      if not endless then
        table.insert(scope_stack, new_frame('method', method_name))
      end
      goto continue
    end

    -- Check for do blocks (need to track for proper end matching)
    -- Must check BEFORE end pattern to properly balance do/end
    if
      line:match(PATTERNS.block_do)
      or line:match(PATTERNS.block_do_with_comment)
      or line:match(PATTERNS.block_do_with_pipes)
    then
      table.insert(scope_stack, new_frame('block', nil))
      goto continue
    end

    -- Check for control flow blocks (if/unless/case/begin/while/until/for)
    if
      line:match(PATTERNS.block_if)
      or line:match(PATTERNS.block_unless)
      or line:match(PATTERNS.block_case)
      or line:match(PATTERNS.block_begin)
      or line:match(PATTERNS.block_begin_with_comment)
      or line:match(PATTERNS.block_while)
      or line:match(PATTERNS.block_until)
      or line:match(PATTERNS.block_for)
    then
      table.insert(scope_stack, new_frame('block', nil))
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
