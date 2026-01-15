-- private-ruby/detect.lua
-- Detection dispatcher - selects between treesitter and regex backends

local config = require("private-ruby.config")
local regex = require("private-ruby.detect.regex")
local treesitter = require("private-ruby.detect.treesitter")

local M = {}

--- Detect private methods in a buffer
--- Dispatches to the appropriate backend based on config
---@param bufnr integer Buffer number
---@return PrivateRubyMark[]
function M.detect(bufnr)
  local cfg = config.get()
  local kind = cfg.detect.kind

  -- Explicit regex mode
  if kind == "regex" then
    return regex.detect(bufnr)
  end

  -- treesitter or auto: try TS first, fallback to regex
  local marks = treesitter.detect(bufnr)
  if marks then
    return marks
  end

  -- Fallback to regex
  return regex.detect(bufnr)
end

return M
