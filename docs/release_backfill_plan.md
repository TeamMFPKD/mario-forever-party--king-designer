# MFMP 历史版本 GitHub Release 补档计划

> 目标：把 `../releases/` 里 2026-02-11 至 2026-11-15 的历史构建，挑成 **31 个 release** 补齐到 GitHub Release。
> 不含增量 PCK、不含自动更新器，只做一次性补档。
> 生成时间 2026-11-17，最后修订 2026-11-17（按"公测前全备 + 公测后按论坛帖"重排）。仓库 `TeamMFPKD/mario-forever-party--king-designer`，分支 `master`（2026-11-18 由 `ee` 改名，远端已同步）。

---

## 1. 现状核对

| 项 | 值 |
| --- | --- |
| 已有 tag | 0 个（本地与远端都没有） |
| 已有 Release | 0 个 |
| 待补档 | **31 个 release**，共 39 个附件 |
| 总体积 | **2.69 GiB**（2890035739 字节） |
| 最大单文件 | 99.9 MB（`mfmp_20261115.apk`），远低于 2 GiB 上限 |
| 关联 commit | 全部可达自 `origin/master`（逐个 `git merge-base --is-ancestor` 校验通过） |

产物的映射规则：每个文件用**自身 mtime** 去 `git log -1 --before=<mtime>` 取当时最新的 commit。
这比"按日期取当天最后一个 commit"准——同一天多次构建能分别落到各自的 commit 上。

### 1.1 收录范围（本次修订的核心）

两条规则：

1. **公测（2026-04-03）之前的构建全部收录。** 从 02-11 首个可联机版到 04-02，共 22 个 release，覆盖联机跑通、移动端、i18n、历史记录、喜欢的关卡、开关砖这些从 0 到 1 的阶段。
2. **公测之后的构建，只收论坛更新帖对应的那一个。** 每个发帖日期选**该日期对应的构建**，共 9 个 release。

为什么"发帖日当天"就是对的版本，而不是 +1/+2 天后的修复版：

- 每个更新帖列出的修复，在发帖**之前**就已全部提交完毕。以 20260408 帖为例，16 项修复全部落在 `04-04 13:14` 到 `04-08 18:36` 之间，而 `mfmp_20260408.rar` 的 commit `0fef00a` 正是 04-08 18:36——**刚好在所有日志条目提交完之后**导出的第一个包。
- 发帖之后的修复属于**下一个**版本。04-08 20:59 的 `4197f2e`（关卡传输信号）出现在 20260413 的帖子里，不在 20260408 的帖子里。
- 因此"发帖日 +1/+2 天"的构建，对应的其实是**下一帖的内容**，收进来会重复。

逐条验证方式：把每个更新帖的每一条日志，找到对应的 commit，再用 `git merge-base --is-ancestor <commit> <构建 commit>` 判断是否包含。9 个已发布版本**全部命中，无一条缺失**。

---

## 2. 节奏：每 2–4 小时一次

31 个 release 按 **2–4 小时不规律间隔**排布，总跨度 **95 小时（约 4 天）**。

每日条数：11-17: 4 个 · 11-18: 7 个 · 11-19: 9 个 · 11-20: 7 个 · 11-21: 4 个

为什么是 2–4 小时而不是连着刷：

1. **二级速率限制**：GitHub 对"产生内容的请求"限制在约 80 次/分钟、500 次/小时。每个 release 是 1 次创建 + N 次上传，31 个连发必然撞限流；撞了之后继续硬推有封账号的风险。
2. **上传不支持断点续传**：单个附件断了要从头传。拉长间隔不能让断的概率变小，但能让重试不叠成雪崩。
3. **留出复盘点**：2–4 小时足够人看一眼结果，发现 tag 打错、附件漏传能立刻停。

排期是**固定种子生成的伪随机序列**（从 2 / 2.5 / 2.75 / 3 / 3.25 / 3.5 / 4 小时中取），所以表里的时间是确定的，不是每次重算都变。

> 实际执行不必精确到分钟。表里的时间是"不早于"的参考值——两次之间隔够 2 小时、没超过 4 小时太多，就符合这个节奏。

---

## 3. 命名与映射

### 3.1 tag 命名

`v<构建日期>`；**同一天有多次构建时加序号** `v<构建日期>-<序号>`：

| 产物 | tag |
| --- | --- |
| `mfmp_20260214.rar` | `v2026.02.14` |
| `mfpkd_20260211.rar` / `mfpkd_20260211_1.rar` | `v2026.02.11-1` / `v2026.02.11-2` |
| `mfmp_20260328.rar` / `_1` / `_2` / `_3` | `v2026.03.28`（合并成一个，见 3.2） |

细节：

- tag 用**构建日期**（文件 mtime 的日期），不是 commit 日期。两者通常同一天，但 `mfmp_20260224.rar` 落在 `2026-02-23 20:30` 的 commit 上，tag 仍按构建日期叫 `v2026.02.24`——玩家认的是"哪天发的版本"。
- tag 用**注解 tag**（`git tag -a`），带 message，方便以后 `git describe`。
- **已存在同名 tag 就跳过**，绝不 `--force` 覆盖。补档前先查一遍。

### 3.2 同日多份产物怎么归类

归档里有两类"一天多份"：

**A. 映射到同一个 commit，大小只差几十 KB** 例如 `mfmp_20260328.rar` / `_1` / `_2` / `_3`（71.0 / 71.1 / 71.0 / 71.1 MB，mtime 相隔 5 分钟到 1 小时），四个文件都落在 commit `3bde370`，是从同一次提交反复导出的。**合并成一个 release**，四个附件都传，tag 用 `v2026.03.28`。

**B. 映射到不同 commit** 例如 2026-02-11 的两份分别落在 `5589112` 和 `9c33b7c`。这是真的两个版本，**拆成两个 release**，tag 加 `-1` / `-2`。

判据只看 **commit hash 是否相同**，不看文件名。

本次收录的 31 个 release 里，属于 A 类的有三组：`v2026.02.12-1`（2 个附件）、`v2026.03.28`（4 个附件）、`v2026.04.08`（2 个附件）。另有 `v2026.11.15` 一个 release 带 4 个附件，但那是**同一次导出的不同平台产物**（exe / pck / apk / rar），不是重复导出。

> `v2026.03.28` 的 4 份可省：只留 `mfmp_20260328.rar` 能省 213 MB。本次按"全备"原则保留全部 4 份。

### 3.3 顺延超过 12 小时的构建

以下构建的 mtime 与它对应 commit 的时间差得很多，说明当天没提交、用了更早的代码打包：

| tag | 产物 | 对应 commit 时间 | 差值 |
| --- | --- | --- | --- |
| `v2026.02.24` | `mfmp_20260224.rar` | 2026-02-23 20:30 | +18.0h |
| `v2026.04.02` | `mfmp_20260402.rar` | 2026-03-31 11:01 | +51.9h |
| `v2026.04.03` | `mfmp_20260403.rar` | 2026-04-02 20:10 | +13.8h |

这些**不修正**，仍按 mtime 定 tag。理由：说明"这个包是哪天导出的、内容是哪次提交"，比强行对齐 commit 日期更贴近事实。

> 注意 `v2026.04.03`：它就是论坛"首次公开发布测试版"那一帖的版本，内容是 04-02 晚上的代码，04-03 上午导出。**它同时是公测前阶段的最后一个包和公测的起点**，清单里只算一次。

---

## 4. 完整补档清单（按顺序执行）

| # | 计划时间 | tag | commit | MB | 提交数 | 附件 | 纪念点 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 2026-11-17 12:00 | `v2026.02.11-1` | `5589112` | 62.1 | 0 | `mfpkd_20260211.rar` | 首个可联机版本（当日 16:42 `We can play`、19:45 `We got result`） |
| 2 | 2026-11-17 14:45 | `v2026.02.11-2` | `9c33b7c` | 62.1 | 2 | `mfpkd_20260211_1.rar` | 修死亡与通过计数存储 |
| 3 | 2026-11-17 18:45 | `v2026.02.12-1` | `c59c329` | 131.6 | 9 | `mfpkd_20260212.rar`<br>`mfpkd_20260212_2.rar` | 结果页诞生、字体替换 |
| 4 | 2026-11-17 20:45 | `v2026.02.12-2` | `d6429d3` | 65.8 | 2 | `mfpkd_20260212_3.rar` | 修非房主结算显示 |
| 5 | 2026-11-18 00:45 | `v2026.02.13-1` | `52ac2a3` | 65.8 | 4 | `mfpkd_20260213.rar` | 屏外喷火食人花禁用 |
| 6 | 2026-11-18 03:45 | `v2026.02.13-2` | `da47ad6` | 65.8 | 2 | `mfpkd_20260213_1.rar` | **移动端操控首次支持** |
| 7 | 2026-11-18 07:15 | `v2026.02.13-3` | `ce7f751` | 65.9 | 5 | `mfpkd_20260213_2.rar` | i18n 选项保存 |
| 8 | 2026-11-18 10:15 | `v2026.02.13-4` | `25a887e` | 65.9 | 1 | `mfpkd_20260213_3.rar` | 标题 BGM 循环修复 |
| 9 | 2026-11-18 14:15 | `v2026.02.14` | `e0334b8` | 65.9 | 8 | `mfmp_20260214.rar` | **改名分界 `mfpkd` → `mfmp`**（02-14 17:13 改导出名） |
| 10 | 2026-11-18 16:45 | `v2026.02.15` | `d23c3d0` | 65.9 | 2 | `mfmp_20260215.rar` | 石盾与实心尖刺、天降崩溃修复 |
| 11 | 2026-11-18 20:15 | `v2026.02.16` | `40327eb` | 65.9 | 11 | `mfmp_20260216.rar` | **接入 GitHub Actions CI** |
| 12 | 2026-11-19 00:15 | `v2026.02.17` | `855c89d` | 65.9 | 8 | `mfmp_20260217.rar` | 坏关模拟器 + 自动封关判定 |
| 13 | 2026-11-19 03:45 | `v2026.02.18` | `5449a61` | 65.9 | 3 | `mfmp_20260218.rar` | 火力花/甜菜获得重力 |
| 14 | 2026-11-19 05:45 | `v2026.02.22` | `dccb5a1` | 68.4 | 23 | `mfmp_20260222.rar` | 控制设置页、日文 i18n、音量选项 |
| 15 | 2026-11-19 09:45 | `v2026.02.24` | `ef0aa68` | 69.1 | 9 | `mfmp_20260224.rar` | **历史记录首次可读关卡**（`We can load history levels!!`） |
| 16 | 2026-11-19 13:15 | `v2026.02.27` | `5c90d02` | 71.0 | 10 | `mfmp_20260227.rar` | 开局倒计时、模块 BGM、准备房间 |
| 17 | 2026-11-19 15:15 | `v2026.03.05` | `e9b4bfc` | 71.0 | 14 | `mfmp_20260305.rar` | 关卡缓存预览、单人奖励、编辑 UI 重排 |
| 18 | 2026-11-19 17:15 | `v2026.03.18` | `ae4fb2a` | 71.0 | 14 | `mfmp_20260318.rar` | **喜欢的关卡功能完成** |
| 19 | 2026-11-19 20:15 | `v2026.03.19` | `18b3316` | 71.0 | 6 | `mfmp_20260319.rar` | 历史/喜欢加载优化（线程加载 + 加载提示） |
| 20 | 2026-11-19 23:15 | `v2026.03.28` | `3bde370` | 284.2 | 20 | `mfmp_20260328.rar`<br>`mfmp_20260328_1.rar`<br>`mfmp_20260328_2.rar`<br>`mfmp_20260328_3.rar` | 编辑器物件可移动与分组（四份同源产物） |
| 21 | 2026-11-20 02:15 | `v2026.03.29` | `c79d66e` | 71.0 | 7 | `mfmp_20260329.rar` | 开关砖上线、移动端按钮布局定稿 |
| 22 | 2026-11-20 05:30 | `v2026.04.02` | `29871bf` | 71.1 | 3 | `mfmp_20260402.rar` | 挤压死亡判定修复 |
| 23 | 2026-11-20 09:30 | `v2026.04.03` | `11e9ef9` | 71.0 | 1 | `mfmp_20260403.rar` | ① 首次公开发布测试版 |
| 24 | 2026-11-20 12:15 | `v2026.04.08` | `0fef00a` | 142.3 | 21 | `mfmp_20260408.rar`<br>`mfmp_20260408_1.rar` | ② 修复部分问题并优化联机 |
| 25 | 2026-11-20 15:45 | `v2026.04.13` | `443d42f` | 71.3 | 16 | `mfmp_20260413.rar` | ③ 优化关卡传输、少量新物件与提示 |
| 26 | 2026-11-20 19:00 | `v2026.04.26-4` | `7a358e6` | 71.3 | 78 | `mfmp_20260426_2.rar` | ④ 玩家/物品新传送方式——透明水管 |
| 27 | 2026-11-20 22:00 | `v2026.05.01-2` | `c66eaa9` | 71.3 | 10 | `mfmp_20260501_1.rar` | ⑤ 更换水管材质、修复部分问题 |
| 28 | 2026-11-21 00:45 | `v2026.05.31` | `3051bd5` | 71.5 | 45 | `mfmp_20260531.rar` | ⑥ 大量新增机关，加入消息系统 |
| 29 | 2026-11-21 04:45 | `v2026.06.04` | `b865683` | 71.6 | 25 | `mfmp_20260604.rar` | ⑦ 修复已知问题，作为稳定版推出 |
| 30 | 2026-11-21 07:30 | `v2026.07.09` | `dc120ad` | 71.8 | 71 | `mfmp_20260709.rar` | ⑧ GALAXY UPDATE |
| 31 | 2026-11-21 11:00 | `v2026.11.15` | `2007d96` | 351.5 | 198 | `mfmp_20261115.exe`<br>`mfmp_20261115.pck`<br>`mfmp_20261115.apk`<br>`mfmp_20261115.rar` | ⑨ CHALLENGE UPDATE |

> "提交数" = 相对上一个 release 之间新增的 commit 数，用于生成 release notes。

---

## 5. 单次操作流程

每个 release 同一套步骤，约 3–8 分钟（取决于附件大小与网速）。

### 5.1 建 tag 并推送

```powershell
git tag -a v2026.02.14 e0334b8 -m "MF: MP build 2026-02-14"
git push origin v2026.02.14
```

> **当前网络状况**：`git ls-remote` 到 GitHub 报 `Connection was reset`，smart-HTTP 通道被阻，`git push` 大概率失败。
> push 不通时改用 API 建 release（5.3），用 `target_commitish` 指定 commit，**tag 由 GitHub 自动建在远端**，不需要本地 push。
> 本地方便时再补 `git tag`，保持本地与远端一致即可。

### 5.2 建 release 并上传附件（有 gh CLI）

```powershell
gh release create v2026.02.14 --title "2026-02-14" --notes-file notes/v2026.02.14.md --target e0334b8
gh release upload v2026.02.14 "../releases/mfmp_20260214.rar"
```

分两步而不是一步带附件：某个附件传失败时只重传它，不用重建 release（重建会换 release ID，下载链接会变）。

### 5.3 没有 gh CLI 时用 API

当前环境没装 `gh`。等价 PowerShell（需要 `GITHUB_TOKEN`，权限至少 `Contents: Read and write`）：

```powershell
$headers = @{
  Authorization = "Bearer $env:GITHUB_TOKEN"
  Accept = "application/vnd.github+json"
  "X-GitHub-Api-Version" = "2022-11-28"
}
$repo = "TeamMFPKD/mario-forever-party--king-designer"

# 1) 建 release（target_commitish 同时决定 tag 指向）
$body = @{
  tag_name         = "v2026.02.14"
  target_commitish = "e0334b8"
  name             = "2026-02-14"
  body             = (Get-Content "notes/v2026.02.14.md" -Raw)
  draft            = $false
  prerelease       = $false
} | ConvertTo-Json

$rel = Invoke-RestMethod -Method Post -Headers $headers -ContentType "application/json" -Uri "https://api.github.com/repos/$repo/releases" -Body $body

# 2) 上传附件（upload_url 里的 {?name,label} 要替换掉）
$name = "mfmp_20260214.rar"
$upload = "https://uploads.github.com/repos/$repo/releases/$($rel.id)/assets?name=$name"
Invoke-RestMethod -Method Post -Headers $headers -ContentType "application/octet-stream" -InFile "../releases/$name" -Uri $upload
```

---

## 6. release notes 写法

正文从 commit 区间直接生成，不手写。

**用 SHA 区间，不要用 tag 区间。** 补档走的是 API，本地不建 tag，写 `v2026.02.13-4..v2026.02.14` 会直接报错：

```powershell
git log --no-merges --reverse --pretty=format:"- %s (%h)" 25a887e..e0334b8
```

区间起点是**上一个 release 的 commit**，终点是本 release 的 commit。第 1 条的起点留空，写"首个归档版本"。

补档的固定开场白（放在正文最前面）：

```markdown
> 本版本为历史构建补档（原构建时间 2026-02-14 21:40）。
> 二进制与当时发布的一致，仅重新托管到 GitHub Releases。
```

---

## 7. 验收

全部完成后核对：

```powershell
$all = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$repo/releases?per_page=100"
"release 数: " + $all.Count                              # 期望 31
"附件总数: " + ($all | ForEach-Object { $_.assets.Count } | Measure-Object -Sum).Sum   # 期望 39
"总体积:   " + ($all | ForEach-Object { $_.assets } | Measure-Object size -Sum).Sum    # 期望 2890035739
```

再逐条对照第 4 节的表：tag、commit、附件名三者一致即通过。

---

## 8. 风险与边界

| 情况 | 处理 |
| --- | --- |
| `git push` 推不上 tag | 用 API 的 `target_commitish` 建 release，tag 由 GitHub 建在远端 |
| 某个附件上传失败 | 单独 `gh release upload` 重传，不重建 release |
| 撞到 429 / 403 | 读 `retry-after` 头，等满再继续；**不要**缩短间隔硬推 |
| tag 名冲突 | 说明之前补过，跳过；不 `--force` |
| 要撤销某个 release | `gh release delete <tag>`；tag 需另外 `git push origin :refs/tags/<tag>` 才删得掉 |
| 玩家下载慢 | 国内访问 `objects.githubusercontent.com` 的通病，与本方案无关；可在正文挂网盘镜像 |
| 归档里某文件损坏 | 补档前先试解压，损坏的不上传，记入"缺档清单" |

---

## 9. 与后续自动化的关系

本文档**只覆盖历史补档**。补完之后，新版本不再走人工流程——CI 已在 2026-11-17 改造完成。

### 9.1 三种触发与对应结果

| 触发 | 构建 | 产物去向 |
| --- | --- | --- |
| push 到 `master` 分支 | Windows + Android + iOS 全量 | 覆盖到**滚动预发布版** `snapshot` |
| push 标签 `v*` | 同上 | 创建/更新该 tag 的**正式 release**，notes 自动生成 |
| `workflow_dispatch` | 同上 | 填 `release_tag` 发正式版；留空则更新 `snapshot` |

日常开发随便 push，产物只是覆盖 `snapshot`（标了 prerelease 的预发布），不会在 Releases 里堆出一串半成品；真要发版时打 tag：

```powershell
git tag -a v2026.11.16 -m "MF: MP build 2026-11-16"
git push origin v2026.11.16
```

### 9.2 实现要点（这些坑已经踩过了）

1. **`permissions: contents: write` 必须显式声明。** 仓库/组织默认给 `GITHUB_TOKEN` 的是只读权限，缺这一行 release 步骤会 403。
2. **发布步骤单独成一个 job，不放矩阵里。** 矩阵每个 job 拿着同一个 token 并发建同一个 tag 的 release，第二个要么 conflict，要么把第一个的附件覆盖掉。现在的做法是矩阵只负责构建+上传 artifact，`release` job 用 `needs: builds` + `download-artifact(merge-multiple: true)` 汇总后一次性发布。
3. **两个 workflow 共用 `concurrency.group: release-${{ github.ref }}`。** Windows/Android 和 iOS 是两个 workflow，都会往同一个 release 追加附件，不串行就会互相踩。
4. **`snapshot` 标签要强制移动。** 滚动版用固定 tag `snapshot` 复用同一个 release，每次先 `git tag -f snapshot $GITHUB_SHA` 再 force push，release 页面才显示正确的提交，否则永远停在第一次的 commit 上。
5. **`overwrite_files` 默认就是 `true`。** 同名的 `mfmp.exe`/`mfmp.apk` 每次构建文件名不变，靠这个覆盖，不会越积越多。

### 9.3 与补档的关系

补档用的 tag 形如 `v2026.02.14`，与新版本走**同一条时间线、同一套命名**，不会出现两套编号。

一个要注意的地方：补档是往历史 commit 上打 tag，而 CI 的 `on: push: tags: ['v*']` 会在**每次推 tag 时触发构建**。所以：

- **补档产生的 tag 不要用 `git push` 推**，用 API 的 `target_commitish` 建 release（第 5.1、5.3 节的做法），GitHub 自动建的 tag **不会触发 workflow**。这条正好和"当前 `git push` 到 GitHub 不通"的现状一致。
- 如果你后来网络通了、想补 `git push origin v2026.02.14`，会**额外触发一次全平台构建**，白烧 Actions 分钟数（macOS 那个按 10 倍计费）。真要推，先确认这个 tag 不需要构建。
