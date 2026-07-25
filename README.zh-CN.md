<div align="center">
  <h1>vv-log-hl.nvim</h1>
  <p><a href="./README.md">English</a> | 中文</p>
  <img src="https://github.com/beixiyo/vv-log-hl.nvim/releases/download/assets-2026-07-25/vv-log-hl.png" alt="vv-log-hl 演示" width="900" />
  <p>想要我的 Neovim 配置？查看 <a href="https://github.com/beixiyo/dotfiles">dotfiles</a></p>
  <em>日志文件语法高亮 — 等级关键词着色 + 圆角 badge 装饰</em>
  <p>
  <img src="https://img.shields.io/badge/Neovim-0.10+-57A143?style=flat-square&logo=neovim&logoColor=white" alt="Requires Neovim 0.10+" />
  <img src="https://img.shields.io/badge/Lua-2C2D72?style=flat-square&logo=lua&logoColor=white" alt="Lua" />
  <img src="https://img.shields.io/badge/zero_deps-✓-2ea44f?style=flat-square" alt="Zero Dependencies" />
  </p>
</div>

---

## 安装

```lua
{
  'beixiyo/vv-log-hl.nvim',
  ft = 'log',
  ---@type VVLogHlConfig
  opts = {
    extension = 'log',     -- 按扩展名检测 filetype（string | string[]）
    filename = {},          -- 按完整文件名检测（string | string[]）
    pattern = {},           -- 按 Lua pattern 匹配路径检测（string | string[]）
    badge = true,           -- 是否启用圆角 badge 效果（Powerline 圆角字符 extmark）
    keyword = {
      error = {},           -- 追加到 error 等级的自定义关键词
      warning = {},
      info = {},
      debug = {},
      pass = {},
    },
  },
}
```

## 配置

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `extension` | `string \| string[]` | `'log'` | 按扩展名注册 filetype |
| `filename` | `string \| string[]` | `{}` | 按完整文件名注册 filetype |
| `pattern` | `string \| string[]` | `{}` | 按 Lua pattern 匹配路径注册 filetype |
| `badge` | `boolean` | `true` | 启用圆角 badge（extmark inline 虚拟文本，不修改 buffer） |
| `keyword` | `table<string, string \| string[]>` | `{}` | 自定义关键词，按等级分组追加 |

### 内置等级关键词

| 等级 | 关键词（大小写不敏感） |
|------|----------------------|
| **Fatal** | `fatal`, `emerg`, `emergency`, `alert`, `crit`, `critical`, `panic` |
| **Error** | `error`, `err`, `errors`, `fail`, `failed`, `failure` |
| **Warning** | `warn`, `warning` |
| **Notice** | `notice` |
| **Info** | `info` |
| **Debug** | `debug`, `dbg`, `trace`, `verbose` |
| **Pass** | `pass`, `passed`, `success`, `done`, `ok`, `complete`, `finished` |
