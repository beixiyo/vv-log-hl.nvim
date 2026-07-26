-- Highlight definitions for log levels, syntax groups and badge caps.

local M = {}

local DIM_BACKGROUND = '#292e42'

local level_colors = {
  fatal = '#f7768e',
  emergency = '#f7768e',
  alert = '#f7768e',
  critical = '#f7768e',
  error = '#db4b4b',
  fail = '#db4b4b',
  warning = '#e0af68',
  notice = '#ff9e64',
  info = '#7aa2f7',
  debug = '#636d83',
  trace = '#636d83',
  verbose = '#636d83',
  pass = '#9ece6a',
  success = '#9ece6a',
}

local syntax_highlights = {
  VVLogDate = { fg = '#e0af68' },
  VVLogWeekdayStr = { fg = '#e0af68' },
  VVLogTime = { fg = '#ff9e64' },
  VVLogTimeAMPM = { fg = '#ff9e64' },
  VVLogTimeZone = { fg = '#ff9e64' },
  VVLogDuration = { fg = '#ff9e64' },
  VVLogNumber = { fg = '#d19a66' },
  VVLogNumberFloat = { fg = '#d19a66' },
  VVLogNumberHex = { fg = '#d19a66' },
  VVLogString = { fg = '#98c379' },
  VVLogBool = { fg = '#d19a66' },
  VVLogNull = { fg = '#d19a66' },
  VVLogUrl = { fg = '#7aa2f7', underline = true },
  VVLogIPv4 = { fg = '#bb9af7' },
  VVLogUUID = { fg = '#bb9af7' },
  VVLogPath = { fg = '#7aa2f7' },
  VVLogSymbol = { fg = '#636d83' },
  VVLogSeparatorLine = { fg = '#636d83' },
}

local badge_caps = {
  Fatal = level_colors.fatal,
  Error = level_colors.error,
  Warning = level_colors.warning,
  Notice = level_colors.notice,
  Info = level_colors.info,
  Debug = DIM_BACKGROUND,
  Pass = level_colors.pass,
}

local function is_dim(level)
  return level == 'debug' or level == 'trace' or level == 'verbose'
end

local function level_highlight(level, color, badge)
  if not badge then
    return is_dim(level)
        and { fg = color }
        or { fg = color, bold = true }
  end

  return is_dim(level)
      and { fg = color, bg = DIM_BACKGROUND }
      or { fg = '#ffffff', bg = color, bold = true }
end

---@param badge boolean
---@return table<string, vim.api.keyset.highlight>
local function definitions(badge)
  local highlights = vim.deepcopy(syntax_highlights)

  for level, color in pairs(level_colors) do
    local title = level:sub(1, 1):upper() .. level:sub(2)
    highlights['VVLogLv' .. title] = level_highlight(level, color, badge)
  end

  if badge then
    for level, color in pairs(badge_caps) do
      highlights['VVLogCap' .. level] = { fg = color }
    end
  end

  return highlights
end

---@param badge boolean
function M.apply(badge)
  for name, highlight in pairs(definitions(badge)) do
    vim.api.nvim_set_hl(0, name, highlight)
  end
end

function M.clear()
  for name in pairs(definitions(true)) do
    vim.api.nvim_set_hl(0, name, {})
  end
end

return M
