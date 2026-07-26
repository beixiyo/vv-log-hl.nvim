-- Enable and disable side effects for highlights and badge decoration.

local Badge = require('vv-log-hl.badge')
local Highlights = require('vv-log-hl.highlights')

local M = {}

local COLOR_GROUP = 'VVLogHighlightColors'
local BADGE_GROUP = 'VVLogHighlightBadge'
local LOG_FILETYPE = 'log'

local enabled = false

local function attach_loaded_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == LOG_FILETYPE then
      Badge.attach(buf)
    end
  end
end

---@return boolean
function M.enabled()
  return enabled
end

---@param config VVLogHlConfig
function M.enable(config)
  if enabled then return end
  enabled = true

  Highlights.apply(config.badge)
  local color_group = vim.api.nvim_create_augroup(COLOR_GROUP, { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = color_group,
    callback = function() Highlights.apply(config.badge) end,
  })

  if not config.badge then return end

  local badge_group = vim.api.nvim_create_augroup(BADGE_GROUP, { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    group = badge_group,
    pattern = LOG_FILETYPE,
    callback = function(event) Badge.attach(event.buf) end,
  })
  attach_loaded_buffers()
end

function M.disable()
  if not enabled then return end
  enabled = false

  vim.api.nvim_create_augroup(COLOR_GROUP, { clear = true })
  vim.api.nvim_create_augroup(BADGE_GROUP, { clear = true })
  Badge.detach_all()
  Highlights.clear()
end

return M
