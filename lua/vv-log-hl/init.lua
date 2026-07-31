-- Public facade: configuration, filetype registration and lifecycle commands.
require('vv-log-hl.types')

local Lifecycle = require('vv-log-hl.lifecycle')
local Syntax = require('vv-log-hl.syntax')

local M = {}

local LOG_FILETYPE = 'log'

---@type VVLogHl.Config
local defaults = {
  extension = LOG_FILETYPE,
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

local config = vim.deepcopy(defaults)
local detector_enabled = true
local owned_filetypes = {}

---@param path string
---@param as_pattern? boolean
---@return string
local function normalize_path(path, as_pattern)
  local normalized = path:gsub('\\', '/')
  if normalized:find('^~') then
    normalized = (as_pattern and vim.pesc(vim.env.HOME) or vim.env.HOME) .. normalized:sub(2)
  end
  return normalized
end

---@param values? string|string[]
---@return string[]
local function list(values)
  if type(values) == 'string' then values = { values } end
  return type(values) == 'table' and values or {}
end

---@param pattern string
---@return string?
local function expand_pattern(pattern)
  local missing = false
  local expanded = pattern:gsub('%${(%S-)}', function(name)
    local value = vim.env[name]
    if value == nil then missing = true end
    return vim.pesc(value or '')
  end)
  return not missing and expanded or nil
end

---@param path string
---@return boolean
local function matches_filename(path)
  local tail = vim.fs.basename(path)
  for _, filename in ipairs(list(config.filename)) do
    local candidate = normalize_path(filename)
    if candidate == path or candidate == tail then return true end
  end
  return false
end

---@param path string
---@return boolean
local function matches_pattern(path)
  local tail = vim.fs.basename(path)
  local cwd = normalize_path(vim.fn.getcwd())
  local prefix = cwd == '/' and cwd or (cwd .. '/')
  local relative = path:sub(1, #prefix) == prefix and path:sub(#prefix + 1) or nil

  for _, configured in ipairs(list(config.pattern)) do
    local pattern = expand_pattern(normalize_path(configured, true))
    if pattern then
      pattern = '^' .. pattern .. '$'
      if pattern:find('/') then
        if path:match(pattern) or (relative and relative:match(pattern)) then return true end
      elseif tail:match(pattern) then
        return true
      end
    end
  end
  return false
end

---@param path string
---@return boolean
local function matches_extension(path)
  local extension = path:match('%.([^.]-)$') or ''
  for _, configured in ipairs(list(config.extension)) do
    if configured == extension then return true end
  end
  return false
end

---@param path string
---@param buf? integer
---@return string?
---@return fun(buf: integer)?
local function detect_filetype(path, buf)
  if not detector_enabled then return nil end

  path = normalize_path(path)
  if matches_filename(path) or matches_pattern(path) or matches_extension(path) then
    return LOG_FILETYPE, function(detected_buf)
      if detected_buf == buf and vim.api.nvim_buf_is_valid(detected_buf) then
        owned_filetypes[detected_buf] = true
      end
    end
  end
end

local function register_filetype_detector()
  -- vim.filetype.add 没有 unregister。单一 pattern dispatcher 不覆盖具体 detector；
  -- 重配后返回 nil，Neovim 会继续执行原 pattern / extension 函数及其 on_detect。
  -- exact filename 的优先级高于 pattern，发生冲突时保留原 detector。
  vim.filetype.add({
    pattern = {
      ['.*()'] = { detect_filetype, { priority = math.huge } },
    },
  })
end

---@param buf integer
local function release_buffer_filetype(buf)
  if not owned_filetypes[buf] then return end
  owned_filetypes[buf] = nil
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= LOG_FILETYPE then return end

  local previous_detector_state = detector_enabled
  detector_enabled = false
  local ok, err = xpcall(function()
    local name = vim.api.nvim_buf_get_name(buf)
    local filetype, on_detect, is_fallback = vim.filetype.match({ buf = buf, filename = name })
    if on_detect then on_detect(buf) end
    if filetype then
      vim.api.nvim_buf_call(buf, function()
        vim.api.nvim_cmd({
          cmd = 'setfiletype',
          args = is_fallback and { 'FALLBACK', filetype } or { filetype },
        }, {})
      end)
    else
      vim.bo[buf].filetype = ''
    end
  end, debug.traceback)
  detector_enabled = previous_detector_state
  if not ok then error(err, 0) end
end

local function release_owned_filetypes()
  local buffers = {}
  for buf in pairs(owned_filetypes) do buffers[#buffers + 1] = buf end
  for _, buf in ipairs(buffers) do release_buffer_filetype(buf) end
end

local function register_commands()
  local commands = {
    VVLogHlEnable = M.enable,
    VVLogHlDisable = M.disable,
    VVLogHlToggle = M.toggle,
  }

  for name, callback in pairs(commands) do
    vim.api.nvim_create_user_command(name, callback, { force = true })
  end
end

---@param buf integer
local function detect_buffer(buf)
  if not vim.api.nvim_buf_is_loaded(buf) then return end
  if vim.bo[buf].filetype == 'bigfile' then return end

  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' or detect_filetype(name) ~= LOG_FILETYPE then
    release_buffer_filetype(buf)
    return
  end
  if vim.bo[buf].filetype == LOG_FILETYPE then return end

  owned_filetypes[buf] = true
  vim.bo[buf].filetype = LOG_FILETYPE
end

local function register_filetype_autocmds()
  local group = vim.api.nvim_create_augroup('VVLogHlFiletype', { clear = true })
  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile', 'BufFilePost' }, {
    group = group,
    callback = function(event) detect_buffer(event.buf) end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    callback = function(event) owned_filetypes[event.buf] = nil end,
  })
end

local function detect_loaded_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    detect_buffer(buf)
  end
end

function M.enable()
  Lifecycle.enable(config)
end

function M.disable()
  Lifecycle.disable()
  Syntax.clear()
end

function M.toggle()
  if Lifecycle.enabled() then
    M.disable()
  else
    M.enable()
  end
end

---@param opts? VVLogHl.Config
function M.setup(opts)
  if Lifecycle.enabled() then Lifecycle.disable() end
  release_owned_filetypes()

  config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
  register_filetype_detector()
  register_filetype_autocmds()
  Syntax.generate(config.keyword)
  register_commands()
  M.enable()
  detect_loaded_buffers()
end

---@return VVLogHl.Config
function M.get_config()
  return vim.deepcopy(config)
end

return M
