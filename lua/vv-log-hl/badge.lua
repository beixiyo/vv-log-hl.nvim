--- 为日志等级关键词添加圆角 badge 效果
--- 使用 extmark inline 虚拟文本在关键词前后插入 Powerline 圆角字符

local M = {}

local ns = vim.api.nvim_create_namespace('log_highlight_badge')

--- 关键词（全小写） -> cap 高亮组（大小写不敏感匹配）
---@type table<string, string>
local keyword_to_cap = {}

local keyword_map = {
  VVLogCapFatal   = { 'fatal', 'emerg', 'emergency', 'alert', 'crit', 'critical', 'panic' },
  VVLogCapError   = { 'error', 'err', 'errors', 'fail', 'failed', 'failure' },
  VVLogCapWarning = { 'warn', 'warning' },
  VVLogCapNotice  = { 'notice' },
  VVLogCapInfo    = { 'info' },
  VVLogCapDebug   = { 'debug', 'dbg', 'trace', 'verbose' },
  VVLogCapPass    = { 'pass', 'passed', 'success', 'done', 'ok', 'complete', 'finished' },
}

for hl, words in pairs(keyword_map) do
  for _, w in ipairs(words) do
    keyword_to_cap[w] = hl
  end
end

-- 按长度降序排列，优先匹配长词
local keywords_sorted = {}
for kw in pairs(keyword_to_cap) do
  keywords_sorted[#keywords_sorted + 1] = kw
end
table.sort(keywords_sorted, function(a, b) return #a > #b end)

-- 构建 Lua pattern：用 | 不行（Lua 没有），逐个匹配
-- 改用 vim.regex 一次编译

--- 判断字符是否为单词字符
---@param str string
---@param pos number 1-indexed
---@return boolean
local function is_word_char(str, pos)
  if pos < 1 or pos > #str then return false end
  local byte = str:byte(pos)
  return (byte >= 48 and byte <= 57)   -- 0-9
      or (byte >= 65 and byte <= 90)   -- A-Z
      or (byte >= 97 and byte <= 122)  -- a-z
      or byte == 95                    -- _
end

--- 为一行添加 badge 圆角
---@param bufnr number
---@param lnum number 0-indexed
---@param line string
local function decorate_line(bufnr, lnum, line)
  local line_lower = line:lower()
  for _, kw in ipairs(keywords_sorted) do
    local start = 1
    while true do
      local s, e = line_lower:find(kw, start, true)  -- plain match on lowercase
      if not s then break end

      -- 检查单词边界
      local before_ok = not is_word_char(line, s - 1)
      local after_ok = not is_word_char(line, e + 1)

      if before_ok and after_ok then
        local cap_hl = keyword_to_cap[kw]
        local col_start = s - 1  -- 转为 0-indexed
        local col_end = e        -- 0-indexed exclusive

        vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, col_start, {
          virt_text = { { '', cap_hl } },
          virt_text_pos = 'inline',
          right_gravity = false,
        })
        vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, col_end, {
          virt_text = { { '', cap_hl } },
          virt_text_pos = 'inline',
          right_gravity = true,
        })
      end

      start = e + 1
    end
  end
end

--- 装饰指定行范围
---@param bufnr number
---@param start_line number 0-indexed，含
---@param end_line number 0-indexed，不含（-1 表示到末尾）
local function decorate_range(bufnr, start_line, end_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  for i, line in ipairs(lines) do
    decorate_line(bufnr, start_line + i - 1, line)
  end
end

--- 装饰整个 buffer
---@param bufnr number
local function decorate_buf(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  decorate_range(bufnr, 0, -1)
end

--- 启用 badge 装饰
function M.attach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  decorate_buf(bufnr)

  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf, _, firstline, lastline, new_lastline)
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then return end
        -- 清除变更范围内的旧装饰
        vim.api.nvim_buf_clear_namespace(buf, ns, firstline, new_lastline)
        -- 仅重新装饰变更行
        decorate_range(buf, firstline, new_lastline)
      end)
    end,
  })
end

return M
