# Changelog

## [0.1.1] - 2026-07-26

### Fixed

- 禁用时立即解除日志 buffer 的 `on_lines` 监听，避免未再次编辑便重新启用后叠加重复监听与重绘

### Changed

- 将高亮、生命周期与自定义 syntax 生成逻辑拆分为独立模块，保持公开配置与命令入口不变

## [0.1.0] - 2026-07-13

### Fixed

- 超大日志卡顿 / 大文件保护被绕过：`badge.attach` 逐行扫描整 buffer 无行数上限，超大 `.log` 会卡住编辑器；且 `setup` 的「补刷 filetype」循环会把 vv-utils.bigfile 已标成 `bigfile` 的大文件强提回 `log`，连带重新打开被 bigfile 关掉的重开销特性。现 `badge.attach` 先用 `vv-utils.bigfile.is_big()` 判定大文件直接跳过，补刷循环也跳过 `filetype=='bigfile'` 的 buffer（与 color-picker 的 `ignore_ft` 一致），日志着色仍由 bigfile 重挂的 syntax 提供
- `:VVLogHlDisable` 此前只清空 `color_group` / `badge_group` 两个 augroup，对已打开的 log buffer 完全无效：badge extmark 与 `nvim_buf_attach` 的 `on_lines` 回调都未移除，syntax 着色也原样保留（高亮根本不消失）；现 `disable()` 调 `badge.detach_all()` 清除全部 badge extmark 并解绑回调，同时 `clear_highlights()` 清空 `VVLog*` 高亮组定义，使 syntax 着色一并失色
- `disable→enable`（或 `:VVLogHlToggle` 两次）后已打开的 log buffer 不会恢复 badge：`enable()` 只建 `FileType` autocmd，而对「已是 `ft=log` 且已加载」的 buffer 该事件不会再触发；现 `enable()` 主动遍历 `nvim_list_bufs()` 对已加载 log buffer 回放 `badge.attach`，配合上一条使 toggle 对已打开 buffer 可逆
- `badge.attach` 无去重保护，`FileType=log` 多次触发（`:set ft=log`、`:e` 重载等）会叠加多个 `on_lines` 回调、每次编辑做 N 倍重复装饰；现以 per-buffer token 机制保证幂等：重复 attach 只重绘不叠加回调，旧回调在 detach 或被新一轮 attach 取代后于下次触发自解绑（return true），并补 `on_detach` 在 buffer wipe 时清表
- 增量重绘漏算 `right_gravity` 漂移：收尾 badge 用 `right_gravity=true`，在行增删时会漂移到变更区下一行而逃出 `[firstline, new_lastline)` 清除范围，留下孤儿 badge 或让被推移的关键词行漏绘；现把清除+重绘范围下界扩展一行（`new_lastline + 1`，按行数封顶）
