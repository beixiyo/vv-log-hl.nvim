# vv-log-hl.nvim

日志文件语法高亮插件，基于 Vim syntax 实现等级关键词着色，并通过 extmark 为关键词添加圆角 badge 效果。

![screenshot](https://img.shields.io/badge/screenshot-placeholder-lightgrey)

## 特性

- 基于 Vim syntax 的日志等级关键词高亮
- 圆角 badge 装饰（Powerline 圆角字符 `` ``，通过 extmark inline 虚拟文本）
- 自定义关键词扩展
- 灵活的文件检测（扩展名 / 文件名 / pattern）
- 增量装饰：编辑时仅重绘变更行，性能优异

## 依赖

无外部依赖。

## 安装

### lazy.nvim

```lua
{
  'beixiyo/vv-log-hl.nvim',
  ft = 'log',
  opts = {
    -- 配置项见下方
  },
}
```

### 手动

```lua
require('vv-log-hl').setup({
  -- 配置项见下方
})
```

## 配置

所有可选项及其默认值：

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `extension` | `string \| string[]` | `'log'` | 按扩展名检测 filetype |
| `filename` | `string \| string[]` | `{}` | 按完整文件名检测 filetype |
| `pattern` | `string \| string[]` | `{}` | 按 Lua pattern 匹配路径检测 filetype |
| `badge` | `boolean` | `true` | 是否启用圆角 badge 效果 |
| `keyword` | `table<string, string \| string[]>` | *见下方* | 自定义关键词，按等级分组 |

### 默认 keyword 配置

```lua
keyword = {
  error = {},    -- 追加到 error 等级的自定义关键词
  warning = {},  -- 追加到 warning 等级
  info = {},     -- 追加到 info 等级
  debug = {},    -- 追加到 debug 等级
  pass = {},     -- 追加到 pass 等级
}
```

自定义关键词会生成 `after/syntax/log.vim` 文件并自动加入 runtimepath。

## 支持的等级与关键词

### 内置关键词（badge 自动识别）

| 等级 | 关键词（大小写不敏感） |
|------|----------------------|
| **Fatal** | `fatal`, `emerg`, `emergency`, `alert`, `crit`, `critical`, `panic` |
| **Error** | `error`, `err`, `errors`, `fail`, `failed`, `failure` |
| **Warning** | `warn`, `warning` |
| **Notice** | `notice` |
| **Info** | `info` |
| **Debug** | `debug`, `dbg`, `trace`, `verbose` |
| **Pass** | `pass`, `passed`, `success`, `done`, `ok`, `complete`, `finished` |

### 添加自定义关键词

```lua
require('vv-log-hl').setup({
  keyword = {
    error = { 'CRITICAL_ERROR', 'FATAL_ERROR' },
    warning = 'DEPRECATION',
    pass = { 'HEALTHY', 'READY' },
  },
})
```

## 文件检测

通过 `vim.filetype.add` 注册，支持三种模式：

```lua
require('vv-log-hl').setup({
  extension = { 'log', 'txt' },         -- *.log, *.txt
  filename = { 'output.log', 'debug' }, -- 精确文件名
  pattern = { '.*/var/log/.*' },        -- Lua pattern 匹配路径
})
```

## Badge 效果

启用 `badge = true`（默认）后，日志等级关键词会被圆角包裹显示：

```
 ERROR  Connection refused
 INFO  Server started on port 3000
 DEBUG  Loading configuration...
```

Badge 使用 extmark inline 虚拟文本实现，不修改 buffer 内容。

## 高亮组

### 等级高亮（badge 背景色）

| 高亮组 | fg | bg | 样式 |
|--------|----|----|------|
| `VVLogLvFatal` | `#ffffff` | `#f7768e` | **bold** |
| `VVLogLvEmergency` | `#ffffff` | `#f7768e` | **bold** |
| `VVLogLvAlert` | `#ffffff` | `#f7768e` | **bold** |
| `VVLogLvCritical` | `#ffffff` | `#f7768e` | **bold** |
| `VVLogLvError` | `#ffffff` | `#db4b4b` | **bold** |
| `VVLogLvFail` | `#ffffff` | `#db4b4b` | **bold** |
| `VVLogLvWarning` | `#ffffff` | `#e0af68` | **bold** |
| `VVLogLvNotice` | `#ffffff` | `#ff9e64` | **bold** |
| `VVLogLvInfo` | `#ffffff` | `#7aa2f7` | **bold** |
| `VVLogLvDebug` | `#a9b1d6` | `#292e42` | - |
| `VVLogLvTrace` | `#a9b1d6` | `#292e42` | - |
| `VVLogLvVerbose` | `#a9b1d6` | `#292e42` | - |
| `VVLogLvPass` | `#ffffff` | `#9ece6a` | **bold** |
| `VVLogLvSuccess` | `#ffffff` | `#9ece6a` | **bold** |

### 圆角 cap 高亮

| 高亮组 | fg |
|--------|-----|
| `VVLogCapFatal` | `#f7768e` |
| `VVLogCapError` | `#db4b4b` |
| `VVLogCapWarning` | `#e0af68` |
| `VVLogCapNotice` | `#ff9e64` |
| `VVLogCapInfo` | `#7aa2f7` |
| `VVLogCapDebug` | `#292e42` |
| `VVLogCapPass` | `#9ece6a` |

高亮组通过 `nvim_set_hl` 设置，切换 colorscheme 时会自动重新应用。

## Testing

Smoke test (zero deps, runs in `-u NONE`):

```bash
nvim --headless -u NONE -l tests/test_smoke.lua
```

Expected: trailing line `X passed, 0 failed`.
