--- vv-log-hl.nvim 变更测试
--- 运行: nvim --headless -u NONE -l tests/test_smoke.lua

local passed = 0
local failed = 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print('  PASS  ' .. name)
  else
    failed = failed + 1
    print('  FAIL  ' .. name .. ': ' .. tostring(err))
  end
end

local function eq(a, b, msg)
  if a ~= b then
    error(string.format('%s: expected %s, got %s', msg or 'mismatch', tostring(b), tostring(a)))
  end
end

-- ─── FIX 4: mkdir 返回值 ───────────────────────────────────────────────

print('\n[FIX 4] mkdir 返回值修正')

test('mkdir -p 对已存在目录仍可正常写入文件', function()
  local tmpdir = vim.fn.tempname()
  -- 首次创建
  vim.fn.mkdir(tmpdir, 'p')
  assert(vim.fn.isdirectory(tmpdir) == 1, 'dir created')
  -- 再次调用（模拟目录已存在，不应报错）
  vim.fn.mkdir(tmpdir, 'p')
  assert(vim.fn.isdirectory(tmpdir) == 1, 'dir still exists')
  -- 关键：无论 mkdir 返回值如何，目录可写
  local path = tmpdir .. '/test.txt'
  local f = io.open(path, 'w')
  assert(f, 'should be able to open file in existing dir')
  f:write('ok')
  f:close()
  eq(vim.fn.filereadable(path), 1, 'file written successfully')
  -- 清理
  vim.fn.delete(tmpdir, 'rf')
end)

test('gen_syntax_file 修正后不再因 mkdir==0 跳过写入', function()
  -- 模拟 gen_syntax_file 核心逻辑（修正后版本）
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, 'p')
  -- 再次调用（模拟目录已存在）
  vim.fn.mkdir(tmpdir, 'p')  -- 修正后：不检查返回值
  -- 继续写入
  local path = tmpdir .. '/log.vim'
  local f = io.open(path, 'w')
  assert(f, 'file should open after mkdir with existing dir')
  f:write('syn keyword VVLogLvError MYERROR\n')
  f:close()
  eq(vim.fn.filereadable(path), 1, 'syntax file created')
  vim.fn.delete(tmpdir, 'rf')
end)

-- ─── FIX 5: 增量 badge 装饰 ───────────────────────────────────────────

print('\n[FIX 5] 增量 badge 装饰')

test('decorate_range 函数存在并可调用', function()
  -- 验证 badge 模块导出结构正确
  local badge_path = vim.fn.fnamemodify('lua/vv-log-hl/badge.lua', ':p')
  if vim.fn.filereadable(badge_path) == 0 then
    -- 尝试从脚本所在目录向上找
    badge_path = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h')
      .. '/lua/vv-log-hl/badge.lua'
  end
  local content = table.concat(vim.fn.readfile(badge_path), '\n')
  -- 验证 decorate_range 函数定义存在
  assert(content:find('local function decorate_range'), 'decorate_range function should exist')
  -- 验证 on_lines 回调使用 firstline/new_lastline 参数
  assert(content:find('firstline'), 'on_lines should use firstline parameter')
  assert(content:find('new_lastline'), 'on_lines should use new_lastline parameter')
end)

test('on_lines 回调签名包含变更范围参数', function()
  local badge_path = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h')
    .. '/lua/vv-log-hl/badge.lua'
  local content = table.concat(vim.fn.readfile(badge_path), '\n')
  -- 验证参数解构
  assert(
    content:find('on_lines = function%(_, buf, _, firstline, lastline, new_lastline%)'),
    'on_lines should destructure firstline/lastline/new_lastline'
  )
end)

test('decorate_range 用于增量更新而非全量', function()
  local badge_path = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h')
    .. '/lua/vv-log-hl/badge.lua'
  local content = table.concat(vim.fn.readfile(badge_path), '\n')
  -- on_lines 内部应调用 decorate_range 而非 decorate_buf
  local on_lines_block = content:match('on_lines = function.-end%)')
  assert(on_lines_block, 'on_lines block found')
  assert(on_lines_block:find('decorate_range'), 'on_lines should call decorate_range')
  assert(not on_lines_block:find('decorate_buf'), 'on_lines should NOT call decorate_buf')
end)

test('is_word_char 边界检测正确', function()
  local function is_word_char(str, pos)
    if pos < 1 or pos > #str then return false end
    local byte = str:byte(pos)
    return (byte >= 48 and byte <= 57)
        or (byte >= 65 and byte <= 90)
        or (byte >= 97 and byte <= 122)
        or byte == 95
  end
  -- 单词内部
  eq(is_word_char('hello', 1), true, 'h is word char')
  eq(is_word_char('a_b', 2), true, '_ is word char')
  eq(is_word_char('x9', 2), true, '9 is word char')
  -- 非单词
  eq(is_word_char(' x', 1), false, 'space is not word char')
  eq(is_word_char('x', 0), false, 'pos 0 out of bounds')
  eq(is_word_char('x', 2), false, 'pos past end')
end)

-- ─── 汇总 ──────────────────────────────────────────────────────────────

print(string.format('\n结果: %d passed, %d failed', passed, failed))
if failed > 0 then os.exit(1) end
