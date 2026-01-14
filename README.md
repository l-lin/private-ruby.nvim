# private-ruby.nvim

Shows private Ruby methods with ghosttext indicators in Neovim.

## Installation

### [lazy.nvim](https://lazy.folke.io/)

```lua
{
  'l-lin/private-ruby.nvim',
  ft = 'ruby',
  opts = {},
}
```

## Configuration

```lua
{
  indicator = {
    text = '',             -- Indicator text (max 2 chars for gutter)
    hl = 'DiagnosticError', -- Highlight group
    position = 'gutter',    -- 'eol' (end of line) or 'gutter' (sign column)
    prefix = '',            -- Prefix before indicator (only for eol)
    -- Optional custom formatter:
    -- format = function(ctx)
    --   return ctx.is_singleton and ' class' or ' '
    -- end,
  },
}
```

### Format function context

When using a custom `format` function, you receive:

- `ctx.method_name` - Method name (string)
- `ctx.is_singleton` - Whether it's a singleton method (boolean)
- `ctx.scope` - Array of `{kind, name}` for enclosing scopes

## Commands

- `:PrivateRubyRefresh` - Manually refresh indicators

## Limitations (v1)

This version uses regex-based detection. Known limitations:

- Does not handle `private :method_name` symbol syntax
- Does not handle `private_class_method`
- May miscount `end` keywords in complex code (heredocs, inline blocks)
- Metaprogramming-defined methods are not detected

## Development

```bash
mise run test   # Run tests with mini.test
mise run smoke  # Smoke test: load plugin
```
