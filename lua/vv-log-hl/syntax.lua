local M = {}

local groups = {
  error = 'VVLogLvError',
  warning = 'VVLogLvWarning',
  info = 'VVLogLvInfo',
  debug = 'VVLogLvDebug',
  pass = 'VVLogLvPass',
}

local runtimepath_added = false

---@param words string|string[]
---@return string?
local function keyword_value(words)
  if type(words) == 'string' then return words end
  if type(words) == 'table' and not vim.tbl_isempty(words) then
    return table.concat(words, ' ')
  end
end

---@param keywords table<string, string|string[]>
function M.generate(keywords)
  local root = vim.fn.stdpath('data') .. '/log-highlight/after'
  local directory = root .. '/syntax'
  local path = directory .. '/log.vim'
  local lines = {}

  for level, words in pairs(keywords) do
    local value = keyword_value(words)
    if groups[level] and value then
      lines[#lines + 1] = ('syn keyword %s %s\n'):format(groups[level], value)
    end
  end

  if vim.tbl_isempty(lines) then
    if vim.fn.filewritable(path) == 1 then vim.fn.delete(path) end
    return
  end

  vim.fn.mkdir(directory, 'p')
  local file = io.open(path, 'w')
  if not file then return end

  file:write(table.concat(lines))
  file:close()

  if not runtimepath_added then
    vim.opt.runtimepath:append(root)
    runtimepath_added = true
  end
end

return M
