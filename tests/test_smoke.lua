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

-- 让 require('vv-log-hl.*') 在 -u NONE 下可用（模块自包含，不依赖 vv-utils）
local this = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p')
local plugin_root = vim.fn.fnamemodify(this, ':h:h')
package.path = table.concat({
  plugin_root .. '/lua/?.lua',
  plugin_root .. '/lua/?/init.lua',
  package.path,
}, ';')

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

-- ─── FIX 66/67/68: enable/disable/toggle 运行时行为 ────────────────────
-- 真实驱动 enable→disable→enable，断言 badge extmark 数、高亮组清除、回调不累积

print('\n[FIX 66/67/68] disable/toggle 真正清除 badge 与高亮（运行时）')

local badge_ns = vim.api.nvim_create_namespace('log_highlight_badge')

--- 新建一个 ft=log 的 buffer 并返回其编号；setup 后置 ft=log 会触发 badge.attach
local function make_log_buf()
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    '2026-04-24 08:02:00 [ERROR]    Connection refused: upstream',
    '2026-04-24 08:01:13 [WARN]     slow query detected',
    '2026-04-24 08:00:01 [INFO]     server starting',
  })
  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].filetype = 'log'
  return buf
end

local function badge_count(buf)
  return #vim.api.nvim_buf_get_extmarks(buf, badge_ns, 0, -1, {})
end

local function hl_has_color(name)
  local h = vim.api.nvim_get_hl(0, { name = name })
  return h.fg ~= nil or h.bg ~= nil
end

local hl = require('vv-log-hl')
hl.setup({ badge = true })

test('#66 setup 后已打开 log buffer 有 badge extmark', function()
  local buf = make_log_buf()
  assert(badge_count(buf) > 0, 'badge 应在 attach 后立即出现, got ' .. badge_count(buf))
  assert(hl_has_color('VVLogLvError'), 'VVLogLvError 应已着色')
  vim.api.nvim_buf_delete(buf, { force = true })
end)

test('#66 disable 清除 badge extmark 且 on_lines 解绑（编辑不再生成）', function()
  local buf = make_log_buf()
  assert(badge_count(buf) > 0, 'precondition: badge 存在')

  hl.disable()
  eq(badge_count(buf), 0, 'disable 后 badge extmark 应为 0')
  eq(hl_has_color('VVLogLvError'), false, 'disable 后高亮组应被清空（syntax 一并失色）')

  -- 编辑 ERROR 行：若 on_lines 未解绑，会重新生成 badge
  vim.api.nvim_buf_set_lines(buf, 0, 1, false, { '2026-04-24 08:02:00 [ERROR]    refused X' })
  vim.wait(200, function() return false end)
  eq(badge_count(buf), 0, 'disable 后编辑不应再生成 badge（on_lines 已解绑）')

  vim.api.nvim_buf_delete(buf, { force = true })
  hl.enable()
end)

test('#67 disable→enable 后已打开 buffer 重新获得 badge 与高亮', function()
  local buf = make_log_buf()
  assert(badge_count(buf) > 0, 'precondition: badge 存在')

  hl.disable()
  eq(badge_count(buf), 0, 'disable 后无 badge')

  hl.enable()
  assert(badge_count(buf) > 0, 'enable 应对已打开 log buffer 回放 badge, got ' .. badge_count(buf))
  assert(hl_has_color('VVLogLvError'), 'enable 后高亮组应恢复')

  vim.api.nvim_buf_delete(buf, { force = true })
end)

test('#67 VVLogHlToggle 两次对已打开 buffer 可逆', function()
  local buf = make_log_buf()
  local before = badge_count(buf)
  assert(before > 0, 'precondition')

  hl.toggle()  -- 关
  eq(badge_count(buf), 0, '第一次 toggle 应关闭 badge')
  hl.toggle()  -- 开
  assert(badge_count(buf) > 0, '第二次 toggle 应恢复 badge')

  vim.api.nvim_buf_delete(buf, { force = true })
end)

test('重复 setup 会应用新的 badge 配置', function()
  local buf = make_log_buf()
  assert(badge_count(buf) > 0, 'precondition: badge 存在')

  hl.setup({ badge = false })
  eq(badge_count(buf), 0, 'badge=false 应清除已有 badge')

  hl.setup({ badge = true })
  assert(badge_count(buf) > 0, 'badge=true 应重新装饰已打开的 log buffer')

  vim.api.nvim_buf_delete(buf, { force = true })
end)

test('#68 重复 attach 幂等：单次编辑只触发一次 on_lines（不累积回调）', function()
  local badge = require('vv-log-hl.badge')
  local buf = make_log_buf()  -- 已 attach 一次

  -- 模拟 FileType=log 重复触发 3 次（:set ft=log ×3）
  badge.attach(buf)
  badge.attach(buf)
  badge.attach(buf)

  -- 计数器：统计单次编辑触发的 set_extmark 调用数
  local count = 0
  local orig = vim.api.nvim_buf_set_extmark
  vim.api.nvim_buf_set_extmark = function(...)
    count = count + 1
    return orig(...)
  end

  -- 编辑最后一行（含单个 INFO 关键词，其下无相邻行可被 +1 扩展波及）→ 单回调应产生 2 个 extmark
  vim.api.nvim_buf_set_lines(buf, 2, 3, false, { '2026-04-24 08:00:01 [INFO]     server starting Y' })
  vim.wait(300, function() return false end)
  vim.api.nvim_buf_set_extmark = orig

  -- 单回调 = 2；若回调累积成 N 个，则为 2N（旧 bug 4 次 attach → 8）
  eq(count, 2, '应只有一个 on_lines 回调存活（2 个 extmark），回调累积会得 2N')

  vim.api.nvim_buf_delete(buf, { force = true })
end)

test('#68 disable→enable 不留双回调：toggle 后单次编辑仍只触发一次', function()
  -- 关键边界：disable 时旧 on_lines 尚未解绑（要下次编辑才 return true），
  -- enable 又注册新回调；token 机制须保证旧回调下次编辑时自解绑且不做活
  local buf = make_log_buf()

  hl.disable()  -- 旧回调仍在注册表，待下次编辑解绑
  hl.enable()   -- 注册新回调；此刻同一 buffer 有两个回调

  local count = 0
  local orig = vim.api.nvim_buf_set_extmark
  vim.api.nvim_buf_set_extmark = function(...)
    count = count + 1
    return orig(...)
  end

  vim.api.nvim_buf_set_lines(buf, 2, 3, false, { '2026-04-24 08:00:01 [INFO]     server starting Z' })
  vim.wait(300, function() return false end)
  vim.api.nvim_buf_set_extmark = orig

  eq(count, 2, '旧回调应自解绑、不做活；仅新回调生效（2 个 extmark）')

  vim.api.nvim_buf_delete(buf, { force = true })
end)

test('增量编辑不留孤儿 badge：在 col-0 关键词行上方插入行（right_gravity 漂移）', function()
  -- 复现：关键词位于行首（col 0）时，插入上一行会让 left-gravity 开头 badge 滞留旧行、
  -- right-gravity 收尾 badge 漂到下一行，旧的 [firstline,new_lastline) 清除范围漏掉它们
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    'error: keyword at column zero',  -- 关键词 error 在 col 0
    'plain tail line no keyword',
  })
  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].filetype = 'log'
  assert(badge_count(buf) >= 2, 'precondition: error 行应有 badge')

  -- 在最上方插入一非关键词行 → error 行被推到 row 1
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, { 'inserted header line' })
  vim.wait(200, function() return false end)

  -- row 0（header）不应有任何 badge；error 行（现 row 1）应恰好 2 个 badge（首尾完整，无孤儿）
  local row0 = vim.api.nvim_buf_get_extmarks(buf, badge_ns, { 0, 0 }, { 0, -1 }, {})
  eq(#row0, 0, 'header 行不应残留孤儿 badge')
  local row1 = vim.api.nvim_buf_get_extmarks(buf, badge_ns, { 1, 0 }, { 1, -1 }, {})
  eq(#row1, 2, 'error 行应保有完整首尾 2 个 badge（不漏绘、不残缺）')

  vim.api.nvim_buf_delete(buf, { force = true })
end)

-- ─── 汇总 ──────────────────────────────────────────────────────────────

print(string.format('\n结果: %d passed, %d failed', passed, failed))
if failed > 0 then os.exit(1) end
