-- private-ruby/detect/treesitter.lua
-- Detect private Ruby methods using Tree-sitter

local types = require('private-ruby.detect.types')
local new_frame = types.new_frame

local M = {}

--- Check if Tree-sitter Ruby parser is available
---@param bufnr integer
---@return boolean, any parser or nil
local function get_parser(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'ruby')
  if not ok or not parser then
    return false, nil
  end
  return true, parser
end

--- Get method name from a method node
---@param node any Tree-sitter node
---@param bufnr integer
---@return string|nil
local function get_method_name(node, bufnr)
  -- Look for the name field (identifier, operator, or setter for method nodes)
  for child in node:iter_children() do
    local child_type = child:type()
    if child_type == 'identifier' or child_type == 'operator' or child_type == 'setter' then
      return vim.treesitter.get_node_text(child, bufnr)
    end
  end
  return nil
end

--- Check if this is a visibility modifier (private/public/protected as standalone)
---@param node any Tree-sitter node
---@param bufnr integer
---@return string|nil visibility type or nil
local function get_visibility_modifier(node, bufnr)
  if node:type() ~= 'identifier' then
    return nil
  end

  local text = vim.treesitter.get_node_text(node, bufnr)
  if text == 'private' or text == 'public' or text == 'protected' then
    -- Make sure it's a standalone modifier (not a method call with arguments)
    local parent = node:parent()
    if parent then
      local parent_type = parent:type()
      -- If it's a direct child of body_statement, it's a modifier
      if parent_type == 'body_statement' then
        return text
      end
      -- If parent is a call and this is the method name, check for no args
      if parent_type == 'call' then
        -- Check if there are arguments
        for sibling in parent:iter_children() do
          if sibling:type() == 'argument_list' then
            -- Has arguments, not a standalone modifier
            return nil
          end
        end
        return text
      end
    end
  end
  return nil
end

--- Detect private methods in a buffer using Tree-sitter
---@param bufnr integer Buffer number
---@return PrivateRubyMark[]|nil marks or nil if TS unavailable
function M.detect(bufnr)
  local ok, parser = get_parser(bufnr)
  if not ok then
    return nil
  end

  local tree_ok, trees = pcall(function()
    return parser:parse()
  end)
  if not tree_ok or not trees or #trees == 0 then
    return nil
  end

  local tree = trees[1]
  local root = tree:root()
  local marks = {}

  --- Walk the tree recursively tracking scope and visibility
  ---@param node any
  ---@param scope_stack ScopeFrame[]
  local function walk(node, scope_stack)
    local node_type = node:type()

    -- Handle module
    if node_type == 'module' then
      local name = nil
      for child in node:iter_children() do
        if child:type() == 'constant' or child:type() == 'scope_resolution' then
          name = vim.treesitter.get_node_text(child, bufnr)
          break
        end
      end
      local new_stack = vim.deepcopy(scope_stack)
      table.insert(new_stack, new_frame('module', name))

      -- Walk children
      for child in node:iter_children() do
        walk(child, new_stack)
      end
      return
    end

    -- Handle singleton_class (class << self)
    if node_type == 'singleton_class' then
      local new_stack = vim.deepcopy(scope_stack)
      table.insert(new_stack, new_frame('singleton', nil))

      for child in node:iter_children() do
        walk(child, new_stack)
      end
      return
    end

    -- Handle class
    if node_type == 'class' then
      local name = nil
      for child in node:iter_children() do
        if child:type() == 'constant' or child:type() == 'scope_resolution' then
          name = vim.treesitter.get_node_text(child, bufnr)
          break
        end
      end
      local new_stack = vim.deepcopy(scope_stack)
      table.insert(new_stack, new_frame('class', name))

      for child in node:iter_children() do
        walk(child, new_stack)
      end
      return
    end

    -- Handle do_block (for Rails DSLs like `concerning`, `class_methods`, etc.)
    -- These blocks may use module_eval/class_eval internally, creating isolated visibility
    if node_type == 'do_block' then
      local new_stack = vim.deepcopy(scope_stack)
      table.insert(new_stack, new_frame('block', nil))

      for child in node:iter_children() do
        walk(child, new_stack)
      end
      return
    end

    -- Handle visibility modifiers
    local visibility = get_visibility_modifier(node, bufnr)
    if visibility then
      -- Update visibility of the nearest enclosing scope
      for i = #scope_stack, 1, -1 do
        scope_stack[i].visibility = visibility
        break
      end
      return
    end

    -- Handle method definitions (regular instance methods)
    if node_type == 'method' then
      local method_name = get_method_name(node, bufnr)
      if method_name then
        -- Check current visibility
        local current_visibility = 'public'
        local in_singleton = false
        for i = #scope_stack, 1, -1 do
          current_visibility = scope_stack[i].visibility
          if scope_stack[i].kind == 'singleton' then
            in_singleton = true
          end
          break
        end

        -- Also check full stack for singleton
        if not in_singleton then
          for _, frame in ipairs(scope_stack) do
            if frame.kind == 'singleton' then
              in_singleton = true
              break
            end
          end
        end

        if current_visibility == 'private' then
          local row = node:start()
          -- Build scope info (excluding singleton for name purposes)
          local scope = {}
          for _, frame in ipairs(scope_stack) do
            table.insert(scope, { kind = frame.kind, name = frame.name })
          end

          table.insert(marks, {
            lnum = row,
            method_name = method_name,
            is_singleton = in_singleton,
            scope = scope,
          })
        end
      end
      -- Don't recurse into method body for visibility
      return
    end

    -- Handle singleton_method (def self.foo) - these are NOT affected by instance private
    if node_type == 'singleton_method' then
      -- Singleton methods with `def self.x` are not affected by instance-level private
      -- We don't mark them here (would need private_class_method)
      return
    end

    -- Handle endless_method (Ruby 3.0+)
    if node_type == 'endless_method' then
      local method_name = get_method_name(node, bufnr)
      if method_name then
        local current_visibility = 'public'
        local in_singleton = false
        for i = #scope_stack, 1, -1 do
          current_visibility = scope_stack[i].visibility
          break
        end
        for _, frame in ipairs(scope_stack) do
          if frame.kind == 'singleton' then
            in_singleton = true
            break
          end
        end

        if current_visibility == 'private' then
          local row = node:start()
          local scope = {}
          for _, frame in ipairs(scope_stack) do
            table.insert(scope, { kind = frame.kind, name = frame.name })
          end

          table.insert(marks, {
            lnum = row,
            method_name = method_name,
            is_singleton = in_singleton,
            scope = scope,
          })
        end
      end
      return
    end

    -- Recurse into children for other nodes
    for child in node:iter_children() do
      walk(child, scope_stack)
    end
  end

  -- Start walking from root with empty scope
  local ok_walk, err = pcall(function()
    walk(root, {})
  end)

  if not ok_walk then
    -- Return nil to trigger fallback
    return nil
  end

  return marks
end

return M
