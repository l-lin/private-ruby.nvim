# private-ruby.nvim

Shows private Ruby methods with ghosttext indicators in Neovim.

## Installation

### [lazy.nvim](https://lazy.folke.io/)

```lua
{
  'l-lin/private-ruby.nvim',
  ft = 'ruby',
  opts = {
    -- Those are the default values:
    indicator = {
      text = '',             -- Indicator text (max 2 chars for gutter)
      hl = 'DiagnosticHint', -- Highlight group
      position = 'gutter',    -- 'eol' (end of line) or 'gutter' (sign column)
      prefix = '',            -- Prefix before indicator (only for eol)
    },
  },
}
```

## Commands

- `:PrivateRubyRefresh` - Manually refresh indicators

## Limitations

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

## License

MIT
