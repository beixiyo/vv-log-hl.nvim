-- Public facade: configuration, filetype registration and lifecycle commands.

local Lifecycle = require('vv-log-hl.lifecycle')
local Syntax = require('vv-log-hl.syntax')

local M = {}

local LOG_FILETYPE = 'log'

---@class VVLogHlConfig
---@field extension? string|string[] @default 'log'
---@field filename? string|string[] @default {}
---@field pattern? string|string[] @default {}
---@field keyword? table<string, string|string[]> @default { error = {}, warning = {}, info = {}, debug = {}, pass = {} }
---@field badge? boolean @default true

---@type VVLogHlConfig
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

---@param values? string|string[]
---@return table<string, string>
local function filetypes(values)
  if not values then return {} end
  if type(values) == 'string' then return { [values] = LOG_FILETYPE } end

  local result = {}
  for _, value in ipairs(values) do
    result[value] = LOG_FILETYPE
  end
  return result
end

local function register_filetypes()
  vim.filetype.add({
    extension = filetypes(config.extension),
    filename = filetypes(config.filename),
    pattern = filetypes(config.pattern),
  })
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

local function detect_loaded_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local filetype = vim.bo[buf].filetype
    if vim.api.nvim_buf_is_loaded(buf)
        and filetype ~= LOG_FILETYPE
        and filetype ~= 'bigfile'
    then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= '' and vim.filetype.match({ buf = buf, filename = name }) == LOG_FILETYPE then
        vim.bo[buf].filetype = LOG_FILETYPE
      end
    end
  end
end

function M.enable()
  Lifecycle.enable(config)
end

function M.disable()
  Lifecycle.disable()
end

function M.toggle()
  if Lifecycle.enabled() then
    M.disable()
  else
    M.enable()
  end
end

---@param opts? VVLogHlConfig
function M.setup(opts)
  if Lifecycle.enabled() then Lifecycle.disable() end

  config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
  register_filetypes()
  Syntax.generate(config.keyword)
  register_commands()
  M.enable()
  detect_loaded_buffers()
end

---@return VVLogHlConfig
function M.get_config()
  return vim.deepcopy(config)
end

return M
