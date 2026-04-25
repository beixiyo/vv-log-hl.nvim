--- log-highlight — 日志文件语法高亮
--- 基于 vim syntax，支持自定义关键词扩展与文件检测

local M = {}

local ft = 'log'

---@class VVLogHighlight.Config
---@field extension? string|string[]
---@field filename? string|string[]
---@field pattern? string|string[]
---@field keyword? table<string, string|string[]>
---@field badge? boolean 是否启用圆角 badge 效果（默认 true）

---@type VVLogHighlight.Config
local defaults = {
  extension = ft,
  filename = {},
  pattern = {},
  badge = true,
  keyword = {
    error = {},
    warning = {},
    info = {},
    debug = {},
    pass = {},
  },
}

local hl_group_map = {
  error = 'VVLogLvError',
  warning = 'VVLogLvWarning',
  info = 'VVLogLvInfo',
  debug = 'VVLogLvDebug',
  pass = 'VVLogLvPass',
}

--- 将 string|string[] 转为 filetype table
---@param values string|string[]|nil
---@return table
local function to_ft_table(values)
  if not values then return {} end

  if type(values) == 'string' then
    return { [values] = ft }
  end

  local t = {}
  for _, v in ipairs(values) do
    t[v] = ft
  end
  return t
end

--- Badge 风格的颜色定义（用 nvim_set_hl，不会被 colorscheme 覆盖）
local badge_highlights = {
  -- 等级：bg + 白色文字
  VVLogLvFatal     = { fg = '#ffffff', bg = '#f7768e', bold = true },
  VVLogLvEmergency = { fg = '#ffffff', bg = '#f7768e', bold = true },
  VVLogLvAlert     = { fg = '#ffffff', bg = '#f7768e', bold = true },
  VVLogLvCritical  = { fg = '#ffffff', bg = '#f7768e', bold = true },
  VVLogLvError     = { fg = '#ffffff', bg = '#db4b4b', bold = true },
  VVLogLvFail      = { fg = '#ffffff', bg = '#db4b4b', bold = true },
  VVLogLvWarning   = { fg = '#ffffff', bg = '#e0af68', bold = true },
  VVLogLvNotice    = { fg = '#ffffff', bg = '#ff9e64', bold = true },
  VVLogLvInfo      = { fg = '#ffffff', bg = '#7aa2f7', bold = true },
  VVLogLvDebug     = { fg = '#a9b1d6', bg = '#292e42' },
  VVLogLvTrace     = { fg = '#a9b1d6', bg = '#292e42' },
  VVLogLvVerbose   = { fg = '#a9b1d6', bg = '#292e42' },
  VVLogLvPass      = { fg = '#ffffff', bg = '#9ece6a', bold = true },
  VVLogLvSuccess   = { fg = '#ffffff', bg = '#9ece6a', bold = true },
  -- 圆角 cap：fg = 等级 bg，无背景
  VVLogCapFatal    = { fg = '#f7768e' },
  VVLogCapError    = { fg = '#db4b4b' },
  VVLogCapWarning  = { fg = '#e0af68' },
  VVLogCapNotice   = { fg = '#ff9e64' },
  VVLogCapInfo     = { fg = '#7aa2f7' },
  VVLogCapDebug    = { fg = '#292e42' },
  VVLogCapPass     = { fg = '#9ece6a' },
}

--- 应用所有 badge 高亮组
local function apply_highlights()
  for name, hl in pairs(badge_highlights) do
    vim.api.nvim_set_hl(0, name, hl)
  end
end

--- 生成 after/syntax/log.vim 扩展自定义关键词
---@param keyword_table table<string, string|string[]>
local function gen_syntax_file(keyword_table)
  local syntax_dir = vim.fn.stdpath('data') .. '/log-highlight/after/syntax'
  local file_path = syntax_dir .. '/log.vim'
  local content = {}

  for level, words in pairs(keyword_table) do
    local str = nil

    if type(words) == 'string' then
      str = words
    elseif type(words) == 'table' and not vim.tbl_isempty(words) then
      str = table.concat(words, ' ')
    end

    if hl_group_map[level] and str then
      content[#content + 1] = 'syn keyword ' .. hl_group_map[level] .. ' ' .. str .. '\n'
    end
  end

  if vim.tbl_isempty(content) then
    if vim.fn.filewritable(file_path) == 1 then
      vim.fn.delete(file_path)
    end
    return
  end

  vim.fn.mkdir(syntax_dir, 'p')

  local file = io.open(file_path, 'w')
  if not file then return end
  file:write(table.concat(content))
  file:close()

  if not M.rtp_added then
    vim.opt.runtimepath:append(vim.fn.stdpath('data') .. '/log-highlight/after')
    M.rtp_added = true
  end
end

---@param opts? VVLogHighlight.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', defaults, opts or {})

  vim.filetype.add({
    extension = to_ft_table(M.config.extension),
    filename = to_ft_table(M.config.filename),
    pattern = to_ft_table(M.config.pattern),
  })

  gen_syntax_file(M.config.keyword)

  -- 应用颜色（立即 + colorscheme 切换后重新应用）
  apply_highlights()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup('VVLogHighlightColors', { clear = true }),
    callback = apply_highlights,
  })

  if M.config.badge then
    local badge = require('vv-log-hl.badge')
    vim.api.nvim_create_autocmd('FileType', {
      pattern = ft,
      group = vim.api.nvim_create_augroup('VVLogHighlightBadge', { clear = true }),
      callback = function(ev)
        badge.attach(ev.buf)
      end,
    })
  end
end

return M
