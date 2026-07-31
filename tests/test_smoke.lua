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

-- ─── syntax / badge 可观察行为 ─────────────────────────────────────────

print('\n[syntax / badge] 真实文件与 extmark 行为')

test('syntax.generate 在既存运行目录写入 syntax 文件', function()
  local syntax = require('vv-log-hl.syntax')
  local path = vim.fn.stdpath('run') .. '/vv-log-hl/after/syntax/log.vim'
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
  syntax.generate({ error = { 'MYERROR', 'OTHER' } })
  local lines = vim.fn.readfile(path)
  assert(vim.fn.filereadable(path) == 1, 'syntax 文件未生成')
  assert(table.concat(lines, '\n'):find('syn keyword VVLogLvError MYERROR OTHER', 1, true), '生成内容缺少 error 关键词')
  syntax.clear()
end)

test('badge 只装饰完整单词边界', function()
  local badge = require('vv-log-hl.badge')
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    'error: standalone',
    'myerror and error_code must not match',
    'ERROR!',
  })
  badge.attach(buf)

  local ns = vim.api.nvim_create_namespace('log_highlight_badge')
  eq(#vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {}), 4, 'only two whole-word error matches receive badges')

  badge.detach(buf)
  vim.api.nvim_buf_delete(buf, { force = true })
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
vim.cmd('filetype on')
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

test('重复 setup 会撤销旧 filetype 规则并启用新规则', function()
  local function matched(path)
    return vim.filetype.match({ filename = path })
  end

  hl.setup({
    extension = 'vvlogold',
    filename = 'vv-log-old-file',
    pattern = 'vv%-log%-old%-pattern%..*',
  })
  eq(matched('/tmp/example.vvlogold'), 'log', '旧 extension 初始应匹配')
  eq(matched('/tmp/vv-log-old-file'), 'log', '旧 filename 初始应匹配')
  eq(matched('/tmp/vv-log-old-pattern.txt'), 'log', '旧 pattern 初始应匹配')

  hl.setup({
    extension = 'vvlognew',
    filename = 'vv-log-new-file',
    pattern = 'vv%-log%-new%-pattern%..*',
  })
  eq(matched('/tmp/example.vvlogold') == 'log', false, '旧 extension 不应继续匹配 log')
  eq(matched('/tmp/vv-log-old-file') == 'log', false, '旧 filename 不应继续匹配 log')
  eq(matched('/tmp/vv-log-old-pattern.txt') == 'log', false, '旧 pattern 不应继续匹配 log')
  eq(matched('/tmp/example.vvlognew'), 'log', '新 extension 应匹配')
  eq(matched('/tmp/vv-log-new-file'), 'log', '新 filename 应匹配')
  eq(matched('/tmp/vv-log-new-pattern.txt'), 'log', '新 pattern 应匹配')
end)

local filetype_fixture_root = vim.fn.tempname()
vim.fn.mkdir(filetype_fixture_root, 'p')

local function fixture_path(name)
  local path = filetype_fixture_root .. '/' .. name
  vim.fn.writefile({ 'fixture' }, path)
  return path
end

local function edit_fixture(name)
  local path = fixture_path(name)
  vim.api.nvim_cmd({ cmd = 'edit', args = { path } }, {})
  return vim.api.nvim_get_current_buf(), path
end

test('真实 BufRead 记录 detector claim，裸 match 不产生 ownership，用户后改 ft 保留', function()
  hl.setup({ extension = 'ts', filename = {}, pattern = {} })

  local raw_buf = vim.api.nvim_create_buf(false, true)
  local raw_path = filetype_fixture_root .. '/raw-match.ts'
  eq(vim.filetype.match({ buf = raw_buf, filename = raw_path }), 'log', '裸 match 应返回当前 detector 结果')
  vim.bo[raw_buf].filetype = 'log'

  hl.setup({ extension = 'vvlogreplacement', filename = {}, pattern = {} })
  eq(vim.bo[raw_buf].filetype, 'log', '只调用裸 match 不得让插件误认 filetype ownership')
  vim.api.nvim_buf_delete(raw_buf, { force = true })

  hl.setup({ extension = 'ts', filename = {}, pattern = {} })
  local claimed_buf = edit_fixture('production-owned.ts')
  eq(vim.bo[claimed_buf].filetype, 'log', '真实 BufRead 应通过 detector on_detect 记录并设置 log')

  local user_buf = edit_fixture('user-overridden.ts')
  eq(vim.bo[user_buf].filetype, 'log', '第二个真实 .ts buffer 也应由当前规则接管')
  vim.bo[user_buf].filetype = 'lua'

  hl.setup({ extension = 'vvlogreplacement', filename = {}, pattern = {} })
  eq(vim.bo[claimed_buf].filetype, 'typescript', '移除规则后应恢复真实 detector 接管的 buffer')
  eq(vim.bo[user_buf].filetype, 'lua', '用户后续修改的 filetype 不得被重配覆盖')

  vim.api.nvim_buf_delete(claimed_buf, { force = true })
  vim.api.nvim_buf_delete(user_buf, { force = true })
end)

test('真实 edit 恢复原 detector，并在 FileType 前运行原 on_detect', function()
  vim.filetype.add({
    extension = {
      vvrestore = function()
        return 'lua', function(buf) vim.b[buf].vv_log_original_detector = 'extension' end
      end,
    },
    filename = {
      ['vv-log-shared-name'] = function()
        return 'lua', function(buf) vim.b[buf].vv_log_original_detector = 'filename' end
      end,
    },
    pattern = {
      ['vv%-log%-shared%-pattern%..*'] = function()
        return 'markdown', function(buf) vim.b[buf].vv_log_original_detector = 'pattern' end
      end,
    },
  })

  local order_group = vim.api.nvim_create_augroup('VVLogHlTestDetectorOrder', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    group = order_group,
    pattern = { 'lua', 'markdown' },
    callback = function(event)
      vim.b[event.buf].vv_log_filetype_saw_detector = vim.b[event.buf].vv_log_original_detector
    end,
  })

  hl.setup({
    extension = 'vvrestore',
    filename = 'vv-log-shared-name',
    pattern = 'vv%-log%-shared%-pattern%..*',
  })

  local exact_path = fixture_path('vv-log-shared-name')
  eq(vim.filetype.match({ filename = exact_path }), 'lua', '裸 match 中既有 exact filename detector 优先')

  local extension_buf = edit_fixture('owned.vvrestore')
  local filename_buf = edit_fixture('vv-log-shared-name')
  local pattern_buf = edit_fixture('vv-log-shared-pattern.txt')
  for _, buf in ipairs({ extension_buf, filename_buf, pattern_buf }) do
    eq(vim.bo[buf].filetype, 'log', '真实 buffer 加载后配置规则应接管为 log')
    vim.b[buf].vv_log_original_detector = nil
    vim.b[buf].vv_log_filetype_saw_detector = nil
  end

  hl.setup({ extension = 'vvlogreplacement', filename = {}, pattern = {} })

  local expected = {
    [extension_buf] = { filetype = 'lua', detector = 'extension' },
    [filename_buf] = { filetype = 'lua', detector = 'filename' },
    [pattern_buf] = { filetype = 'markdown', detector = 'pattern' },
  }
  for buf, value in pairs(expected) do
    eq(vim.bo[buf].filetype, value.filetype, '重配后应恢复原 detector 的 filetype')
    eq(vim.b[buf].vv_log_original_detector, value.detector, '原 on_detect 应在恢复时执行')
    eq(vim.b[buf].vv_log_filetype_saw_detector, value.detector, 'FileType 必须看到 on_detect 初始化状态')
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  vim.api.nvim_del_augroup_by_id(order_group)
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
vim.fn.delete(filetype_fixture_root, 'rf')
if failed > 0 then os.exit(1) end
