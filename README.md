<div align="center">
  <h1>vv-log-hl.nvim</h1>
  <p>English | <a href="./README.zh-CN.md">中文</a></p>
  <img src="https://github.com/beixiyo/vv-log-hl.nvim/releases/download/assets-2026-07-25/vv-log-hl.png" alt="vv-log-hl demo" width="900" />
  <p>Want my Neovim config? See <a href="https://github.com/beixiyo/dotfiles">dotfiles</a></p>
  <em>Syntax highlighting for log files with colored level keywords and rounded badge decorations</em>
  <p>
    <img src="https://img.shields.io/badge/Neovim-0.10+-57A143?style=flat-square&logo=neovim&logoColor=white" alt="Requires Neovim 0.10+" />
    <img src="https://img.shields.io/badge/Lua-2C2D72?style=flat-square&logo=lua&logoColor=white" alt="Lua" />
    <img src="https://img.shields.io/badge/zero_deps-✓-2ea44f?style=flat-square" alt="Zero Dependencies" />
  </p>
</div>

---

## Installation

```lua
{
  'beixiyo/vv-log-hl.nvim',
  ft = 'log',
  ---@type VVLogHlConfig
  opts = {
    extension = 'log',     -- Detect filetype by extension (string | string[])
    filename = {},          -- Detect by exact filename (string | string[])
    pattern = {},           -- Detect paths with Lua patterns (string | string[])
    badge = true,           -- Add rounded Powerline badge extmarks
    keyword = {
      error = {},           -- Additional keywords for the error level
      warning = {},
      info = {},
      debug = {},
      pass = {},
    },
  },
}
```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `extension` | `string \| string[]` | `'log'` | Registers the filetype by extension |
| `filename` | `string \| string[]` | `{}` | Registers the filetype by exact filename |
| `pattern` | `string \| string[]` | `{}` | Registers the filetype when a path matches a Lua pattern |
| `badge` | `boolean` | `true` | Enables rounded badges rendered as inline extmark virtual text without modifying the buffer |
| `keyword` | `table<string, string \| string[]>` | `{}` | Appends custom keywords grouped by level |

### Built-in level keywords

| Level | Keywords, case-insensitive |
|-------|----------------------------|
| **Fatal** | `fatal`, `emerg`, `emergency`, `alert`, `crit`, `critical`, `panic` |
| **Error** | `error`, `err`, `errors`, `fail`, `failed`, `failure` |
| **Warning** | `warn`, `warning` |
| **Notice** | `notice` |
| **Info** | `info` |
| **Debug** | `debug`, `dbg`, `trace`, `verbose` |
| **Pass** | `pass`, `passed`, `success`, `done`, `ok`, `complete`, `finished` |
