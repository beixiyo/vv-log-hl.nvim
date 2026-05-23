--- log-highlight — 日志文件语法高亮
--- 基于 vim syntax，支持自定义关键词扩展与文件检测

local M = {}

local ft = 'log'
local config
local rtp_added = false
local enabled = false
local color_group = 'VVLogHighlightColors'
local badge_group = 'VVLogHighlightBadge'

---@class VVLogHlConfig
---@field extension? string|string[] @default 'log'
---@field filename? string|string[] @default {}
---@field pattern? string|string[] @default {}
---@field keyword? table<string, string|string[]> @default { error = {}, warning = {}, info = {}, debug = {}, pass = {} }
---@field badge? boolean 是否启用圆角 badge 效果 @default true

---@type VVLogHlConfig
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

local level_colors = {
  fatal     = '#f7768e',
  emergency = '#f7768e',
  alert     = '#f7768e',
  critical  = '#f7768e',
  error     = '#db4b4b',
  fail      = '#db4b4b',
  warning   = '#e0af68',
  notice    = '#ff9e64',
  info      = '#7aa2f7',
  debug     = '#636d83',
  trace     = '#636d83',
  verbose   = '#636d83',
  pass      = '#9ece6a',
  success   = '#9ece6a',
}

local syntax_colors = {
  VVLogDate          = { fg = '#e0af68' },
  VVLogWeekdayStr    = { fg = '#e0af68' },
  VVLogTime          = { fg = '#ff9e64' },
  VVLogTimeAMPM      = { fg = '#ff9e64' },
  VVLogTimeZone      = { fg = '#ff9e64' },
  VVLogDuration      = { fg = '#ff9e64' },
  VVLogNumber         = { fg = '#d19a66' },
  VVLogNumberFloat    = { fg = '#d19a66' },
  VVLogNumberHex      = { fg = '#d19a66' },
  VVLogString         = { fg = '#98c379' },
  VVLogBool           = { fg = '#d19a66' },
  VVLogNull           = { fg = '#d19a66' },
  VVLogUrl            = { fg = '#7aa2f7', underline = true },
  VVLogIPv4           = { fg = '#bb9af7' },
  VVLogUUID           = { fg = '#bb9af7' },
  VVLogPath           = { fg = '#7aa2f7' },
  VVLogSymbol         = { fg = '#636d83' },
  VVLogSeparatorLine  = { fg = '#636d83' },
}

local function build_highlights(use_badge)
  local hls = vim.deepcopy(syntax_colors)
  for level, color in pairs(level_colors) do
    local name = 'VVLogLv' .. level:sub(1, 1):upper() .. level:sub(2)
    local is_dim = (level == 'debug' or level == 'trace' or level == 'verbose')
    if use_badge then
      hls[name] = is_dim
        and { fg = color, bg = '#292e42' }
        or  { fg = '#ffffff', bg = color, bold = true }
    else
      hls[name] = is_dim
        and { fg = color }
        or  { fg = color, bold = true }
    end
  end
  if use_badge then
    hls.VVLogCapFatal   = { fg = level_colors.fatal }
    hls.VVLogCapError   = { fg = level_colors.error }
    hls.VVLogCapWarning = { fg = level_colors.warning }
    hls.VVLogCapNotice  = { fg = level_colors.notice }
    hls.VVLogCapInfo    = { fg = level_colors.info }
    hls.VVLogCapDebug   = { fg = '#292e42' }
    hls.VVLogCapPass    = { fg = level_colors.pass }
  end
  return hls
end

local function apply_highlights()
  for name, hl in pairs(build_highlights(config.badge)) do
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

  if not rtp_added then
    vim.opt.runtimepath:append(vim.fn.stdpath('data') .. '/log-highlight/after')
    rtp_added = true
  end
end

function M.enable()
  if enabled then return end
  enabled = true

  apply_highlights()
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = vim.api.nvim_create_augroup(color_group, { clear = true }),
    callback = apply_highlights,
  })

  if config.badge then
    local badge = require('vv-log-hl.badge')
    vim.api.nvim_create_autocmd('FileType', {
      pattern = ft,
      group = vim.api.nvim_create_augroup(badge_group, { clear = true }),
      callback = function(ev)
        badge.attach(ev.buf)
      end,
    })
  end
end

function M.disable()
  if not enabled then return end
  enabled = false
  vim.api.nvim_create_augroup(color_group, { clear = true })
  vim.api.nvim_create_augroup(badge_group, { clear = true })
end

function M.toggle()
  if enabled then
    M.disable()
  else
    M.enable()
  end
end

---@param opts? VVLogHlConfig
function M.setup(opts)
  config = vim.tbl_deep_extend('force', defaults, opts or {})

  vim.filetype.add({
    extension = to_ft_table(config.extension),
    filename = to_ft_table(config.filename),
    pattern = to_ft_table(config.pattern),
  })

  gen_syntax_file(config.keyword)
  M.enable()

  vim.api.nvim_create_user_command('VVLogHlEnable', function() M.enable() end, {})
  vim.api.nvim_create_user_command('VVLogHlDisable', function() M.disable() end, {})
  vim.api.nvim_create_user_command('VVLogHlToggle', function() M.toggle() end, {})

  -- lazy load 时 filetype 检测已跑完，补刷已打开 buffer 的 filetype
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype ~= ft then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= '' then
        local detected = vim.filetype.match({ buf = buf, filename = name })
        if detected == ft then
          vim.bo[buf].filetype = ft
        end
      end
    end
  end
end

---获取当前配置（只读副本）
---@return VVLogHlConfig
function M.get_config()
  return vim.deepcopy(config)
end

return M
