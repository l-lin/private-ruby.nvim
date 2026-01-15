-- private-ruby/render.lua
-- Extmark rendering for private method indicators

local M = {}

local NS_NAME = "private-ruby"

-- Map our config position names to nvim's virt_text_pos values
local POSITION_TO_VIRT_TEXT_POS = {
  virtual_text = 'eol',
  overlay = 'overlay',
  right_align = 'right_align',
  inline = 'inline',
}

--- Get or create the namespace
---@return integer Namespace ID
local function get_namespace()
  return vim.api.nvim_create_namespace(NS_NAME)
end

--- Clear all private-ruby extmarks from a buffer
---@param bufnr integer Buffer number
function M.clear(bufnr)
  local ns = get_namespace()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

--- Render marks on a buffer
---@param bufnr integer Buffer number
---@param marks table[] List of marks with { lnum, text, hl }
---@param cfg table Config with indicator options
function M.render(bufnr, marks, cfg)
  M.clear(bufnr)

  local ns = get_namespace()
  local indicator = cfg.indicator
  local is_gutter = indicator.position == "gutter"

  for _, mark in ipairs(marks) do
    local text = mark.text or indicator.text
    local hl = mark.hl or indicator.hl

    if is_gutter then
      vim.api.nvim_buf_set_extmark(bufnr, ns, mark.lnum, 0, {
        sign_text = text,
        sign_hl_group = hl,
      })
    else
      local virt_pos = POSITION_TO_VIRT_TEXT_POS[indicator.position] or 'eol'
      vim.api.nvim_buf_set_extmark(bufnr, ns, mark.lnum, 0, {
        virt_text = { { text, hl } },
        virt_text_pos = virt_pos,
        hl_mode = "combine",
      })
    end
  end
end

return M
